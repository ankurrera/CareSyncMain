# Triggering Cloud Run build deployment
import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["TORCH_CPP_MIN_LOG_LEVEL"] = "3"
if "DEEPFACE_HOME" not in os.environ:
    os.environ["DEEPFACE_HOME"] = os.getcwd()
import tempfile
import time
import warnings
warnings.filterwarnings("ignore")
import logging
import cv2
import numpy as np
import math
import json
from typing import Dict, Any, List, Optional, Tuple
from fastapi import FastAPI, HTTPException, File, UploadFile, Depends, Request, Header, Form, BackgroundTasks
from fastapi.concurrency import run_in_threadpool
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from dotenv import load_dotenv
from supabase import create_client, Client
# Monkey patch protobuf MessageFactory if needed before importing mediapipe
try:
    import google.protobuf.message_factory as protobuf_message_factory
    if not hasattr(protobuf_message_factory.MessageFactory, "GetPrototype"):
        def _get_prototype(self, descriptor):
            return self.GetMessageClass(descriptor)
        protobuf_message_factory.MessageFactory.GetPrototype = _get_prototype
except Exception:
    pass

import mediapipe as mp
from deepface import DeepFace
from collections import defaultdict

# Initialize MediaPipe FaceMesh singleton for sub-30ms reuse
mp_face_mesh = None

def init_mediapipe():
    global mp_face_mesh
    if mp_face_mesh is not None:
        return
    try:
        mp_face_mesh = mp.solutions.face_mesh.FaceMesh(
            static_image_mode=True,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5
        )
    except Exception as e:
        print(f"Failed to initialize MediaPipe FaceMesh singleton: {e}")

# Trigger early initialization
try:
    init_mediapipe()
except Exception:
    pass

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("production_biometric_api")

# Load environment variables
load_dotenv(dotenv_path="../.env")
load_dotenv(dotenv_path=".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY") or os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    logger.error("Missing Supabase credentials in environment variables.")
    raise ValueError("SUPABASE_URL and SUPABASE_KEY must be set in the environment.")

logger.info(f"Connecting to Supabase at: {SUPABASE_URL}")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI(
    title="CareSync Production Biometric API",
    description="Enterprise-grade biometric face processing microservice with ArcFace, RetinaFace, and pgvector.",
    version="3.0.0"
)

from fastapi.responses import JSONResponse

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    error_code = "SERVER_ERROR"
    message = str(detail)
    if isinstance(detail, dict):
        error_code = detail.get("error_code", "SERVER_ERROR")
        message = detail.get("message", str(detail))
    else:
        if exc.status_code == 401:
            error_code = "UNAUTHORIZED"
        elif exc.status_code == 403:
            error_code = "FORBIDDEN"
        elif exc.status_code == 429:
            error_code = "RATE_LIMITED"
        elif exc.status_code == 404:
            error_code = "NO_MATCH_FOUND"
    
    request_id = request.headers.get("X-Request-Id", "unknown")
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error_code": error_code,
            "message": message,
            "request_id": request_id,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
    )

# ============================================================================
# UTILITIES & IN-MEMORY SYSTEMS
# ============================================================================

# Security Token Validation
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    expected_token = os.getenv("HF_TOKEN")
    if not expected_token:
        logger.error("HF_TOKEN is not set in environment variables! API access is disabled.")
        raise HTTPException(
            status_code=503,
            detail="API authorization is not configured. Access is disabled."
        )
    if token != expected_token:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing API authorization token."
        )
    return token

# Rate Limiter
class RateLimiter:
    def __init__(self, requests_limit: int, window_seconds: int):
        self.requests_limit = requests_limit
        self.window_seconds = window_seconds
        self.history = defaultdict(list)

    def is_allowed(self, key: str) -> bool:
        now = time.time()
        self.history[key] = [t for t in self.history[key] if now - t < self.window_seconds]
        if len(self.history[key]) < self.requests_limit:
            self.history[key].append(now)
            return True
        return False

enroll_limiter = RateLimiter(requests_limit=10, window_seconds=60)
identify_limiter = RateLimiter(requests_limit=15, window_seconds=60)
verify_limiter = RateLimiter(requests_limit=15, window_seconds=60)

# In-Memory TTL Cache for Patient Scan Sessions
class SimpleTTLCache:
    def __init__(self, ttl_seconds: int = 300):
        self.ttl = ttl_seconds
        self.cache = {} # Key: user_id/client_ip -> (result_dict, expiry_time)

    def get(self, key: str) -> Optional[Dict[str, Any]]:
        if key in self.cache:
            val, expiry = self.cache[key]
            if time.time() < expiry:
                return val
            else:
                del self.cache[key]
        return None

    def set(self, key: str, value: Dict[str, Any]):
        self.cache[key] = (value, time.time() + self.ttl)

    def clear(self):
        self.cache.clear()

scan_cache = SimpleTTLCache(ttl_seconds=300)

# Check if PyTorch (Anti-Spoofing Dependency) is available
try:
    import torch
    torch.set_num_threads(1)
    has_torch = True
except ImportError:
    has_torch = False
    logger.error("Torch is not installed. Face anti-spoofing (liveness check) will be bypassed.")

# ============================================================================
# IMAGE QUALITY & POSE ESTIMATION ENGINE
# ============================================================================

def resize_to_consistent_size(img, max_dim=640):
    h, w = img.shape[:2]
    scale = max_dim / max(h, w)
    if abs(scale - 1.0) < 1e-5:
        return img
    new_w = int(w * scale)
    new_h = int(h * scale)
    interpolation = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_CUBIC
    return cv2.resize(img, (new_w, new_h), interpolation=interpolation)

def estimate_face_pose(facial_area: dict) -> Dict[str, float]:
    """
    Estimates roll, yaw, and pitch from the 5-point face landmarks in degrees.
    """
    left_eye = facial_area.get("left_eye")
    right_eye = facial_area.get("right_eye")
    nose = facial_area.get("nose")
    mouth_left = facial_area.get("mouth_left")
    mouth_right = facial_area.get("mouth_right")
    
    roll, yaw, pitch = 0.0, 0.0, 0.0
    
    if left_eye and right_eye:
        dy = right_eye[1] - left_eye[1]
        dx = right_eye[0] - left_eye[0]
        roll = np.degrees(np.arctan2(dy, dx))
        
    if left_eye and right_eye and nose:
        d_left = np.linalg.norm(np.array(nose) - np.array(left_eye))
        d_right = np.linalg.norm(np.array(nose) - np.array(right_eye))
        denom = d_left + d_right
        if denom > 0:
            yaw_ratio = (d_left - d_right) / denom
            yaw = yaw_ratio * 90.0
            
    if left_eye and right_eye and nose and mouth_left and mouth_right:
        y_eyes = (left_eye[1] + right_eye[1]) / 2.0
        y_mouth = (mouth_left[1] + mouth_right[1]) / 2.0
        dist_eyes_mouth = y_mouth - y_eyes
        if dist_eyes_mouth > 0:
            pitch_ratio = (nose[1] - y_eyes) / dist_eyes_mouth
            pitch = (pitch_ratio - 0.55) * 90.0
            
    return {"roll": round(float(roll), 2), "yaw": round(float(yaw), 2), "pitch": round(float(pitch), 2)}

def analyze_face_with_mediapipe(img: np.ndarray) -> Optional[Dict[str, Any]]:
    """
    Runs Google MediaPipe Face Mesh directly on the image.
    Returns estimated pose angles (yaw, pitch, roll) from the 468 landmarks using 3D depth geometry.
    """
    global mp_face_mesh
    if mp_face_mesh is None:
        init_mediapipe()
    if mp_face_mesh is None:
        logger.warning("MediaPipe FaceMesh singleton is None. Skipping MediaPipe analysis.")
        return None

    try:
        h, w = img.shape[:2]
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        results = mp_face_mesh.process(img_rgb)
        
        if not results.multi_face_landmarks:
            return None
            
        landmarks = results.multi_face_landmarks[0].landmark
        
        # 3D points
        p_forehead = np.array([landmarks[10].x, landmarks[10].y, landmarks[10].z])
        p_chin = np.array([landmarks[152].x, landmarks[152].y, landmarks[152].z])
        p_selion = np.array([landmarks[9].x, landmarks[9].y, landmarks[9].z])
        p_left_outer = np.array([landmarks[33].x, landmarks[33].y, landmarks[33].z])
        p_right_outer = np.array([landmarks[263].x, landmarks[263].y, landmarks[263].z])
        p_left_inner = np.array([landmarks[133].x, landmarks[133].y, landmarks[133].z])
        p_right_inner = np.array([landmarks[362].x, landmarks[362].y, landmarks[362].z])
        
        # Vertical axis: combination of forehead-to-chin and selion-to-chin
        v1 = p_chin - p_forehead
        v2 = p_chin - p_selion
        V = (v1 / np.linalg.norm(v1)) + (v2 / np.linalg.norm(v2))
        V = V / np.linalg.norm(V)
        
        # Horizontal axis: combination of outer eyes and inner eyes
        h1 = p_right_outer - p_left_outer
        h2 = p_right_inner - p_left_inner
        H = (h1 / np.linalg.norm(h1)) + (h2 / np.linalg.norm(h2))
        H = H / np.linalg.norm(H)
        
        # Orthogonalize H relative to V
        H = H - np.dot(H, V) * V
        H = H / np.linalg.norm(H)
        
        # Face normal (points forward out of the face)
        N = np.cross(H, V)
        N = N / np.linalg.norm(N)
        
        # Calculate yaw, pitch, roll in degrees
        # N.x corresponds to yaw (left/right)
        # N.y corresponds to pitch (up/down). Note that screen coordinates have Y pointing down,
        # so normal tilting up means it points slightly in the negative Y direction.
        yaw = np.degrees(np.arcsin(N[0]))
        pitch = np.degrees(-np.arcsin(N[1])) + 9.0
        roll = np.degrees(np.arctan2(H[1], H[0]))
        
        # Apply physical range constraints
        yaw = np.clip(yaw, -60.0, 60.0)
        pitch = np.clip(pitch, -60.0, 60.0)
        roll = np.clip(roll, -60.0, 60.0)
        
        # Compute 2D coordinate lists for backwards compatibility and check_face_occlusions
        nose_2d = [landmarks[1].x * w, landmarks[1].y * h, landmarks[1].z * w]
        left_eye_2d = [landmarks[33].x * w, landmarks[33].y * h, landmarks[33].z * w]
        right_eye_2d = [landmarks[263].x * w, landmarks[263].y * h, landmarks[263].z * w]
        mouth_left_2d = [landmarks[61].x * w, landmarks[61].y * h, landmarks[61].z * w]
        mouth_right_2d = [landmarks[291].x * w, landmarks[291].y * h, landmarks[291].z * w]

        return {
            "yaw": round(float(yaw), 2),
            "pitch": round(float(pitch), 2),
            "roll": round(float(roll), 2),
            "landmarks_count": len(landmarks),
            "nose": nose_2d,
            "left_eye": left_eye_2d,
            "right_eye": right_eye_2d,
            "mouth_left": mouth_left_2d,
            "mouth_right": mouth_right_2d,
            "landmarks": landmarks
        }
    except Exception as e:
        logger.warning(f"Error inside analyze_face_with_mediapipe: {e}")
        return None

def check_face_occlusions(img: np.ndarray, facial_area: dict) -> Dict[str, Any]:
    """
    Checks for sunglasses, face masks, or other region obstructions using OpenCV.
    """
    left_eye = facial_area.get("left_eye")
    right_eye = facial_area.get("right_eye")
    nose = facial_area.get("nose")
    mouth_left = facial_area.get("mouth_left")
    mouth_right = facial_area.get("mouth_right")
    
    wearing_sunglasses = False
    wearing_mask = False
    
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    
    if left_eye and right_eye:
        x1 = max(0, int(min(left_eye[0], right_eye[0]) - 0.3 * abs(left_eye[0] - right_eye[0])))
        x2 = min(w, int(max(left_eye[0], right_eye[0]) + 0.3 * abs(left_eye[0] - right_eye[0])))
        y1 = max(0, int(min(left_eye[1], right_eye[1]) - 0.3 * abs(left_eye[0] - right_eye[0])))
        y2 = min(h, int(max(left_eye[1], right_eye[1]) + 0.3 * abs(left_eye[0] - right_eye[0])))
        
        if (x2 - x1) > 5 and (y2 - y1) > 5:
            eye_region = gray[y1:y2, x1:x2]
            eye_mean = np.mean(eye_region)
            face_mean = np.mean(gray)
            if eye_mean < 45.0 or (eye_mean / max(1.0, face_mean)) < 0.45:
                wearing_sunglasses = True
                
    if mouth_left and mouth_right and nose:
        x1 = max(0, int(min(mouth_left[0], mouth_right[0]) - 0.2 * abs(mouth_left[0] - mouth_right[0])))
        x2 = min(w, int(max(mouth_left[0], mouth_right[0]) + 0.2 * abs(mouth_left[0] - mouth_right[0])))
        y1 = max(0, int(nose[1]))
        y2 = min(h, int(max(mouth_left[1], mouth_right[1]) + 0.5 * abs(mouth_left[1] - nose[1])))
        
        if (x2 - x1) > 5 and (y2 - y1) > 5:
            lower_face = gray[y1:y2, x1:x2]
            lower_std = np.std(lower_face)
            if lower_std < 12.0:
                wearing_mask = True
                
    return {
        "wearing_sunglasses": wearing_sunglasses,
        "wearing_mask": wearing_mask
    }

def align_and_crop_with_mediapipe(img: np.ndarray, mp_result: Dict[str, Any]) -> Dict[str, Any]:
    h, w = img.shape[:2]
    landmarks = mp_result["landmarks"]
    
    # Eye centers as midpoint of outer and inner corners
    # Left eye: outer is 33, inner is 133
    left_eye_x = (landmarks[33].x + landmarks[133].x) / 2.0 * w
    left_eye_y = (landmarks[33].y + landmarks[133].y) / 2.0 * h
    
    # Right eye: outer is 263, inner is 362
    right_eye_x = (landmarks[263].x + landmarks[362].x) / 2.0 * w
    right_eye_y = (landmarks[263].y + landmarks[362].y) / 2.0 * h
    
    # Nose tip is 1
    nose_x = landmarks[1].x * w
    nose_y = landmarks[1].y * h
    
    # Mouth left corner is 61
    mouth_left_x = landmarks[61].x * w
    mouth_left_y = landmarks[61].y * h
    
    # Mouth right corner is 291
    mouth_right_x = landmarks[291].x * w
    mouth_right_y = landmarks[291].y * h
    
    # Source points for similarity transform mapping (3 key landmarks to define face plane)
    src_pts = np.array([
        [left_eye_x, left_eye_y],
        [right_eye_x, right_eye_y],
        [(mouth_left_x + mouth_right_x) / 2.0, (mouth_left_y + mouth_right_y) / 2.0]
    ], dtype=np.float32)
    
    # Standard reference coordinates for 112x112 ArcFace template (Eyes & Mouth center)
    ref_pts = np.array([
        [30.2946, 51.6963],  # Left eye center
        [81.7054, 51.6963],  # Right eye center
        [56.0000, 92.2041]   # Mouth center midpoint
    ], dtype=np.float32)
    
    # Estimate similarity transform matrix (2x3)
    M, _ = cv2.estimateAffinePartial2D(src_pts, ref_pts)
    
    if M is not None:
        cropped = cv2.warpAffine(img, M, (112, 112))
    else:
        logger.warning("Similarity transform estimation failed. Falling back to simple eye-based crop.")
        # Fallback to simple crop if transform fails
        left_eye = mp_result["left_eye"]
        right_eye = mp_result["right_eye"]
        face_w = abs(right_eye[0] - left_eye[0]) * 2.0
        face_h = face_w * 1.2
        xmin = max(0, int(min(left_eye[0], right_eye[0]) - face_w * 0.2))
        xmax = min(w, int(max(left_eye[0], right_eye[0]) + face_w * 0.2))
        ymin = max(0, int(min(left_eye[1], right_eye[1]) - face_h * 0.3))
        ymax = min(h, int(max(left_eye[1], right_eye[1]) + face_h * 0.5))
        cropped = img[ymin:ymax, xmin:xmax]
        if cropped.size == 0:
            cropped = img
        cropped = cv2.resize(cropped, (112, 112))
        
    # Standard output scale [0, 1] float32
    cropped_normalized = cropped.astype(np.float32) / 255.0
    
    # Calculate bounding box in original image for preview/diagnostics
    xs = [left_eye_x, right_eye_x, nose_x, mouth_left_x, mouth_right_x]
    ys = [left_eye_y, right_eye_y, nose_y, mouth_left_y, mouth_right_y]
    xmin_orig = min(xs)
    xmax_orig = max(xs)
    ymin_orig = min(ys)
    ymax_orig = max(ys)
    
    fw = xmax_orig - xmin_orig
    fh = ymax_orig - ymin_orig
    
    facial_area = {
        "x": int(max(0, xmin_orig - 0.25 * fw)),
        "y": int(max(0, ymin_orig - 0.35 * fh)),
        "w": int(min(w, xmax_orig + 0.25 * fw) - max(0, xmin_orig - 0.25 * fw)),
        "h": int(min(h, ymax_orig + 0.20 * fh) - max(0, ymin_orig - 0.35 * fh)),
        "left_eye": (int(left_eye_x), int(left_eye_y)),
        "right_eye": (int(right_eye_x), int(right_eye_y)),
        "nose": (int(nose_x), int(nose_y)),
        "mouth_left": (int(mouth_left_x), int(mouth_left_y)),
        "mouth_right": (int(mouth_right_x), int(mouth_right_y))
    }
    
    return {
        "face": cropped_normalized,
        "facial_area": facial_area,
        "confidence": 1.0
    }

def detect_and_align_face(img, is_id_doc=False, run_liveness=False, mp_result: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    # If pre-computed MediaPipe landmarks exist and it is not an ID document, crop/align in python directly (~2ms)
    if mp_result is not None and not is_id_doc:
        try:
            logger.info("Aligning and cropping face using pre-computed MediaPipe FaceMesh landmarks.")
            face = align_and_crop_with_mediapipe(img, mp_result)
            
            # Check liveness if requested using skip detector backend (fast)
            if run_liveness and has_torch:
                logger.info("Running liveness check on the MediaPipe face with padded context.")
                
                # The anti-spoofing model requires surrounding head/background context to detect
                # screens/spoofs. We crop a padded face region (60% padding) to preserve context.
                try:
                    h, w = img.shape[:2]
                    landmarks = mp_result["landmarks"]
                    xs = [lm.x * w for lm in landmarks]
                    ys = [lm.y * h for lm in landmarks]
                    min_x, max_x = min(xs), max(xs)
                    min_y, max_y = min(ys), max(ys)
                    
                    face_w = max_x - min_x
                    face_h = max_y - min_y
                    
                    pad_x = face_w * 0.6
                    pad_y = face_h * 0.6
                    
                    x1 = max(0, int(min_x - pad_x))
                    y1 = max(0, int(min_y - pad_y))
                    x2 = min(w, int(max_x + pad_x))
                    y2 = min(h, int(max_y + pad_y))
                    
                    padded_crop = img[y1:y2, x1:x2]
                    
                    liveness_res = DeepFace.extract_faces(
                        img_path=padded_crop,
                        detector_backend="skip",
                        align=False,
                        enforce_detection=False,
                        anti_spoofing=True
                    )
                except Exception as liveness_err:
                    logger.warning(f"Failed to prepare padded liveness crop: {liveness_err}. Falling back to full image liveness.")
                    liveness_res = DeepFace.extract_faces(
                        img_path=img,
                        detector_backend="skip",
                        align=False,
                        enforce_detection=False,
                        anti_spoofing=True
                    )
                
                if liveness_res and len(liveness_res) > 0:
                    is_real = liveness_res[0].get("is_real", True)
                    if not is_real:
                        raise HTTPException(
                            status_code=400,
                            detail={
                                "error_code": "LIVENESS_FAILED",
                                "message": "Liveness check failed. Spoofing attempt blocked."
                            }
                        )
            return face
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(f"MediaPipe-based python crop/align failed: {e}. Falling back to standard detection...")

    # Standard extraction fallback (used for ID documents, or when MediaPipe pre-check fails)
    primary_backend = "mediapipe" if not is_id_doc else "retinaface"
    backends_to_try = [primary_backend]
    if primary_backend == "mediapipe":
        backends_to_try.append("retinaface")

    last_exc = None
    for backend in backends_to_try:
        try:
            logger.info(f"Extracting face using DeepFace backend: {backend}")
            faces = DeepFace.extract_faces(
                img_path=img,
                detector_backend=backend,
                align=True,
                enforce_detection=True,
                anti_spoofing=(run_liveness and has_torch)
            )
            if not faces or len(faces) == 0:
                continue

            if len(faces) > 1:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "MULTIPLE_FACES",
                        "message": "Multiple faces detected. Please capture only one person."
                    }
                )

            face = faces[0]
            face_conf = face.get("confidence", 0.0)
            
            # MediaPipe detector confidence scores in DeepFace can sometimes be lower than 0.85 
            # even for perfectly valid front-facing mesh results. 
            # Therefore, we only enforce the strict 0.85 threshold on retinaface.
            if backend == "retinaface" and face_conf < 0.85:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "LOW_CONFIDENCE",
                        "message": "Face detection confidence too low. Verify lighting and angle."
                    }
                )

            facial_area = face["facial_area"]
            wf, hf = facial_area["w"], facial_area["h"]
            if wf < 120 or hf < 120:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_SMALL",
                        "message": "Face too small or too far. Please move closer."
                    }
                )

            if run_liveness and has_torch:
                is_real = face.get("is_real", True)
                if not is_real:
                    raise HTTPException(
                        status_code=400,
                        detail={
                            "error_code": "LIVENESS_FAILED",
                            "message": "Liveness check failed. Spoofing attempt blocked."
                        }
                    )

            return face

        except HTTPException:
            # Re-raise standard HTTPExceptions (like MULTIPLE_FACES, FACE_TOO_SMALL, LIVENESS_FAILED)
            # directly to avoid swallowing genuine client-side errors during backend fallback.
            raise
        except Exception as e:
            last_exc = e
            logger.warning(f"Backend '{backend}' failed during extraction: {e}")
            continue

    # If all backends in the chain failed to detect any face:
    raise HTTPException(
        status_code=400,
        detail={
            "error_code": "NO_FACE_DETECTED",
            "message": "No face detected. Please ensure a clear face is visible." if is_id_doc else "No face detected. Please position the camera directly in front of the face."
        }
    )

def evaluate_image_quality(img_input: Any, run_liveness: bool = False, extract_face_crop: bool = True, target_pose: Optional[str] = None) -> Dict[str, Any]:
    start_time = time.time()
    if isinstance(img_input, str):
        img = cv2.imread(img_input)
    else:
        img = img_input

    if img is None:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_IMAGE",
                "message": "Cannot read image."
            }
        )

    h_orig, w_orig = img.shape[:2]
    if h_orig < 320 or w_orig < 320:
        raise HTTPException(
            status_code=400, 
            detail={
                "error_code": "FACE_TOO_SMALL",
                "message": f"Image resolution too low ({w_orig}x{h_orig}). Minimum is 320x320 pixels."
            }
        )

    img_resized = resize_to_consistent_size(img, max_dim=640)
    h, w, c = img_resized.shape

    gray = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)
    mean_brightness = np.mean(gray)
    if mean_brightness < 40 and extract_face_crop:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "LOW_LIGHT",
                "message": "Lighting too dark. Please illuminate the face."
            }
        )
    if mean_brightness > 225 and extract_face_crop:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "OVER_EXPOSED",
                "message": "Lighting too bright. Please adjust lighting."
            }
        )

    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    if laplacian_var < 65.0 and extract_face_crop:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "IMAGE_BLUR",
                "message": "Image blurred or out of focus. Please hold camera still."
            }
        )

    contrast_score = np.std(gray)
    if contrast_score < 20 and extract_face_crop:
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "INVALID_IMAGE",
                "message": "Image contrast too low."
            }
        )

    # Primary pipeline: MediaPipe Face Mesh
    start_mp = time.time()
    mp_result = None
    try:
        mp_result = analyze_face_with_mediapipe(img_resized)
    except Exception as mp_err:
        logger.warning(f"MediaPipe Face Mesh processing error: {mp_err}")
    mp_time = (time.time() - start_mp) * 1000.0

    start_extraction = time.time()
    # Optimized preview path (skip RetinaFace/DeepFace if MediaPipe succeeded and crop is not required)
    if mp_result is not None and not extract_face_crop:
        landmarks = mp_result["landmarks"]
        x_coords = [lm.x * w for lm in landmarks]
        y_coords = [lm.y * h for lm in landmarks]
        xmin, xmax = min(x_coords), max(x_coords)
        ymin, ymax = min(y_coords), max(y_coords)
        
        facial_area = {
            "x": int(xmin),
            "y": int(ymin),
            "w": int(xmax - xmin),
            "h": int(ymax - ymin),
            "left_eye": mp_result["left_eye"][:2],
            "right_eye": mp_result["right_eye"][:2],
            "nose": mp_result["nose"][:2],
            "mouth_left": mp_result["mouth_left"][:2],
            "mouth_right": mp_result["mouth_right"][:2]
        }
        
        occlusions = check_face_occlusions(img_resized, facial_area)
        eyes_visible = True
        face_confidence = 1.0
        cropped_face = np.zeros((112, 112, 3), dtype=np.uint8) # Dummy face crop
        pose = {
            "yaw": mp_result["yaw"],
            "pitch": mp_result["pitch"],
            "roll": mp_result["roll"]
        }
        face_area_px = facial_area["w"] * facial_area["h"]
        total_area_px = h * w
        face_percentage = (face_area_px / total_area_px) * 100.0
        
        logger.info(f"MediaPipe FaceMesh (Preview Optimized) -> Yaw: {pose['yaw']}°, Pitch: {pose['pitch']}°, Roll: {pose['roll']}°")
    else:
        # Standard extraction (used for Enrollment/ID, or fallback when MediaPipe fails)
        if mp_result is None:
            logger.warning("MediaPipe failed on current frame. RetinaFace fallback activated.")
        
        face = detect_and_align_face(img_resized, is_id_doc=False, run_liveness=run_liveness, mp_result=mp_result)
        facial_area = face["facial_area"]
        occlusions = check_face_occlusions(img_resized, facial_area)
        eyes_visible = (facial_area.get("left_eye") is not None) and (facial_area.get("right_eye") is not None)
        face_confidence = face.get("confidence", 0.0 if mp_result is None else 1.0)
        cropped_face = face["face"]
        
        if mp_result is not None:
            pose = {
                "yaw": mp_result["yaw"],
                "pitch": mp_result["pitch"],
                "roll": mp_result["roll"]
            }
            logger.info(f"MediaPipe FaceMesh (Standard) -> Yaw: {pose['yaw']}°, Pitch: {pose['pitch']}°, Roll: {pose['roll']}°")
        else:
            pose = estimate_face_pose(facial_area)
            logger.info("RetinaFace -> Bounding box pose estimation complete.")
            
        face_area_px = facial_area["w"] * facial_area["h"]
        total_area_px = h * w
        face_percentage = (face_area_px / total_area_px) * 100.0

    extraction_time = (time.time() - start_extraction) * 1000.0
    quality_score = min(1.0, (laplacian_var / 120.0)) * (1.0 - abs(128.0 - mean_brightness) / 128.0)
    total_quality_time = (time.time() - start_time) * 1000.0

    # ── POSE CONFIDENCE & DYNAMIC GUIDANCE (Phases 4 & 5) ──────────────────
    capture_score = 0.0
    capture_eligible = False
    error_code = None
    reason = None
    instruction = "Keep your face steady"

    centered = False
    lighting_good = False
    sharpness_good = False
    pose_valid = False
    occlusion_free = False
    size_good = False
    dev_x = 1.0
    dev_y = 1.0
    
    pose_confidence = 100.0

    if not facial_area or face_confidence < 0.3:
        error_code = "FACE_NOT_DETECTED"
        instruction = "Position your face in the circle"
        reason = "No face detected in the frame"
    else:
        # 1. Centering Calculations
        center_x = facial_area["x"] + facial_area["w"] / 2.0
        center_y = facial_area["y"] + facial_area["h"] / 2.0
        dev_x = abs(center_x - w / 2.0) / (w / 2.0)
        dev_y = abs(center_y - h / 2.0) / (h / 2.0)
        face_center_score = max(0.0, 1.0 - max(dev_x, dev_y) * 2.0)
        centered = bool(dev_x <= 0.25 and dev_y <= 0.25)
        
        # 2. Lighting Calculations
        dev_bright = abs(mean_brightness - 125.0) / 85.0
        lighting_score = max(0.0, 1.0 - dev_bright)
        lighting_good = bool(60.0 <= mean_brightness <= 220.0)
        
        # 3. Sharpness Calculations
        sharpness_score = min(1.0, laplacian_var / 120.0)
        sharpness_good = bool(laplacian_var >= 65.0)
        
        # 4. Occlusion Check
        occlusion_free = not occlusions.get("any_occluded", False)
        occlusion_score = 1.0 if occlusion_free else 0.0
        
        # 5. Face Size Calculations
        # target percentage around 28% of frame
        dev_size = abs(face_percentage - 28.0) / 15.0
        face_size_score = max(0.0, 1.0 - dev_size)
        size_good = bool(18.0 <= face_percentage <= 40.0)
        
        # 6. Pose Calculations
        yaw = pose.get("yaw", 0.0)
        pitch = pose.get("pitch", 0.0)
        roll = pose.get("roll", 0.0)
        
        logger.info(f"[POSE_DEBUG] target_pose={target_pose} yaw={yaw:+.1f} pitch={pitch:+.1f} roll={roll:+.1f}")
        
        roll_good = bool(abs(roll) <= 15.0)
        
        # Target Pose calculations
        pose_angle_score = 1.0
        pose_valid = False
        
        if target_pose:
            t_pose = target_pose.lower()
            if t_pose in ["neutral", "smile"]:
                dev_yaw = abs(yaw) / 10.0
                dev_pitch = abs(pitch) / 8.0
                dev_roll = abs(roll) / 15.0
                pose_angle_score = max(0.0, 1.0 - max(dev_yaw, dev_pitch, dev_roll))
                
                yaw_ok = bool(-10.0 <= yaw <= 10.0)
                pitch_ok = bool(-8.0 <= pitch <= 8.0)
                pose_valid = yaw_ok and pitch_ok and roll_good
                
                if not pose_valid:
                    if not roll_good:
                        instruction = "Keep your head straight"
                        reason = f"Roll angle ({roll:+.1f}°) exceeds straight threshold (±15°)"
                    elif not yaw_ok:
                        instruction = "Turn slightly RIGHT" if yaw < -10.0 else "Turn slightly LEFT"
                        reason = f"Yaw angle ({yaw:+.1f}°) exceeds neutral range (±10°)"
                    elif not pitch_ok:
                        instruction = "Lower your chin" if pitch > 8.0 else "Raise your chin"
                        reason = f"Pitch angle ({pitch:+.1f}°) exceeds neutral range (±8°)"
            elif t_pose == "left":
                dev_yaw = abs(yaw - (-35.0)) / 15.0
                dev_pitch = abs(pitch) / 12.0
                dev_roll = abs(roll) / 15.0
                pose_angle_score = max(0.0, 1.0 - max(dev_yaw, dev_pitch, dev_roll))
                
                yaw_ok = bool(-50.0 <= yaw <= -20.0)
                pitch_ok = bool(-12.0 <= pitch <= 12.0)
                pose_valid = yaw_ok and pitch_ok and roll_good
                
                if not pose_valid:
                    if not roll_good:
                        instruction = "Keep your head straight"
                        reason = f"Roll angle ({roll:+.1f}°) exceeds straight threshold (±15°)"
                    elif not yaw_ok:
                        instruction = "Turn your head LEFT" if yaw > -20.0 else "Turn your head back slightly"
                        reason = f"Yaw angle ({yaw:+.1f}°) invalid for Left pose (-50° to -20°)"
                    elif not pitch_ok:
                        instruction = "Lower your chin" if pitch > 12.0 else "Raise your chin"
                        reason = f"Pitch angle ({pitch:+.1f}°) invalid for Left pose (±12°)"
            elif t_pose == "right":
                dev_yaw = abs(yaw - 35.0) / 15.0
                dev_pitch = abs(pitch) / 12.0
                dev_roll = abs(roll) / 15.0
                pose_angle_score = max(0.0, 1.0 - max(dev_yaw, dev_pitch, dev_roll))
                
                yaw_ok = bool(20.0 <= yaw <= 50.0)
                pitch_ok = bool(-12.0 <= pitch <= 12.0)
                pose_valid = yaw_ok and pitch_ok and roll_good
                
                if not pose_valid:
                    if not roll_good:
                        instruction = "Keep your head straight"
                        reason = f"Roll angle ({roll:+.1f}°) exceeds straight threshold (±15°)"
                    elif not yaw_ok:
                        instruction = "Turn your head RIGHT" if yaw < 20.0 else "Turn your head back slightly"
                        reason = f"Yaw angle ({yaw:+.1f}°) invalid for Right pose (20° to 50°)"
                    elif not pitch_ok:
                        instruction = "Lower your chin" if pitch > 12.0 else "Raise your chin"
                        reason = f"Pitch angle ({pitch:+.1f}°) invalid for Right pose (±12°)"
            elif t_pose == "up":
                dev_pitch = abs(pitch - (-25.0)) / 10.0
                dev_yaw = abs(yaw) / 12.0
                dev_roll = abs(roll) / 15.0
                pose_angle_score = max(0.0, 1.0 - max(dev_yaw, dev_pitch, dev_roll))
                
                pitch_ok = bool(-35.0 <= pitch <= -15.0)
                yaw_ok = bool(-12.0 <= yaw <= 12.0)
                pose_valid = pitch_ok and yaw_ok and roll_good
                
                if not pose_valid:
                    if not roll_good:
                        instruction = "Keep your head straight"
                        reason = f"Roll angle ({roll:+.1f}°) exceeds straight threshold (±15°)"
                    elif not pitch_ok:
                        instruction = "Raise your chin" if pitch > -15.0 else "Lower your chin slightly"
                        reason = f"Pitch angle ({pitch:+.1f}°) invalid for Up pose (-35° to -15°)"
                    elif not yaw_ok:
                        instruction = "Turn head slightly RIGHT" if yaw < -12.0 else "Turn head slightly LEFT"
                        reason = f"Yaw angle ({yaw:+.1f}°) invalid for Up pose (±12°)"
            elif t_pose == "down":
                dev_pitch = abs(pitch - 25.0) / 10.0
                dev_yaw = abs(yaw) / 12.0
                dev_roll = abs(roll) / 15.0
                pose_angle_score = max(0.0, 1.0 - max(dev_yaw, dev_pitch, dev_roll))
                
                pitch_ok = bool(15.0 <= pitch <= 35.0)
                yaw_ok = bool(-12.0 <= yaw <= 12.0)
                pose_valid = pitch_ok and yaw_ok and roll_good
                
                if not pose_valid:
                    if not roll_good:
                        instruction = "Keep your head straight"
                        reason = f"Roll angle ({roll:+.1f}°) exceeds straight threshold (±15°)"
                    elif not pitch_ok:
                        instruction = "Lower your chin" if pitch < 15.0 else "Raise your chin slightly"
                        reason = f"Pitch angle ({pitch:+.1f}°) invalid for Down pose (15° to 35°)"
                    elif not yaw_ok:
                        instruction = "Turn head slightly RIGHT" if yaw < -12.0 else "Turn head slightly LEFT"
                        reason = f"Yaw angle ({yaw:+.1f}°) invalid for Down pose (±12°)"
        else:
            pose_valid = True

        # Calculate capture score based on weighted sub-metrics
        capture_score = (
            35.0 * pose_angle_score +
            20.0 * face_center_score +
            15.0 * sharpness_score +
            15.0 * lighting_score +
            15.0 * face_size_score
        ) * occlusion_score
        
        # Rule-based Capture Eligibility check (Phase 1)
        if not occlusion_free:
            capture_eligible = False
            error_code = "FACE_OCCLUDED"
            instruction = "Remove mask or sunglasses"
            reason = "Face occlusions detected in eye or mouth regions"
        elif not centered:
            capture_eligible = False
            error_code = "FACE_NOT_CENTERED"
            instruction = "Center your face in the circle"
            reason = f"Face center (X deviation: {dev_x*100:.1f}%, Y deviation: {dev_y*100:.1f}%) exceeds alignment tolerance"
        elif not size_good:
            capture_eligible = False
            if face_percentage < 18.0:
                error_code = "FACE_TOO_SMALL"
                instruction = "Move closer"
                reason = f"Face percentage in frame ({face_percentage:.1f}%) is below 18%"
            else:
                error_code = "FACE_TOO_LARGE"
                instruction = "Move back slightly"
                reason = f"Face percentage in frame ({face_percentage:.1f}%) exceeds 40%"
        elif not lighting_good:
            capture_eligible = False
            if mean_brightness < 60.0:
                error_code = "POOR_LIGHTING"
                instruction = "Move to a brighter area"
                reason = f"Mean brightness ({mean_brightness:.1f}) is too dark"
            else:
                error_code = "OVER_EXPOSED"
                instruction = "Avoid direct bright light"
                reason = f"Mean brightness ({mean_brightness:.1f}) is overexposed"
        elif not sharpness_good:
            capture_eligible = False
            error_code = "IMAGE_BLUR"
            instruction = "Hold still (Image is blurry)"
            reason = f"Laplacian variance ({laplacian_var:.1f}) is below sharpness threshold"
        elif not pose_valid:
            capture_eligible = False
            error_code = "WRONG_POSE"
            # instruction and reason are already configured in target_pose calculations
        else:
            capture_eligible = True
            error_code = None
            reason = None
            if target_pose:
                t_pose = target_pose.lower()
                if t_pose == "smile":
                    instruction = "Hold still and smile naturally"
                else:
                    instruction = f"Hold still and look {t_pose}"
            else:
                instruction = "Hold still"

        # Compatibility assignment
        pose_confidence = capture_score
        guidance = instruction

    # Detailed Frame logging (Phase 7)
    yaw = pose.get("yaw", 0.0)
    pitch = pose.get("pitch", 0.0)
    roll = pose.get("roll", 0.0)
    logger.info(
        f"\nRequested Pose: {target_pose or 'none'}\n"
        f"Detected Pose: {target_pose or 'none' if pose_valid else 'incorrect'}\n"
        f"Yaw: {yaw:+.1f}°\n"
        f"Pitch: {pitch:+.1f}°\n"
        f"Roll: {roll:+.1f}°\n"
        f"Centered: {centered} (dev_x={dev_x:.2f}, dev_y={dev_y:.2f})\n"
        f"Sharpness: {laplacian_var:.1f} (good={sharpness_good})\n"
        f"Brightness: {mean_brightness:.1f} (good={lighting_good})\n"
        f"Face Size: {face_percentage:.1f}% (good={size_good})\n"
        f"Occluded: {not occlusion_free}\n"
        f"Pose Valid: {pose_valid}\n"
        f"Capture Score: {capture_score:.1f}%\n"
        f"Capture Eligible: {capture_eligible}\n"
        f"Failure Reason: {reason or 'none'}\n"
    )

    logger.info(
        f"evaluate_image_quality timing -> MediaPipe: {mp_time:.1f}ms | "
        f"Extraction: {extraction_time:.1f}ms | Total: {total_quality_time:.1f}ms"
    )

    return {
        "success": True,
        "quality_score": float(quality_score),
        "sharpness": float(laplacian_var),
        "brightness": float(mean_brightness),
        "face_confidence": float(face_confidence),
        "cropped_face": cropped_face,
        "pose": pose,
        "occlusions": occlusions,
        "eyes_visible": bool(eyes_visible),
        "face_percentage_in_frame": round(float(face_percentage), 2),
        "pose_confidence": round(float(pose_confidence), 2),
        "guidance": guidance,
        "capture_eligible": bool(capture_eligible),
        "capture_score": round(float(capture_score), 2),
        "centered": centered,
        "lighting_good": lighting_good,
        "sharpness_good": sharpness_good,
        "pose_valid": pose_valid,
        "error_code": error_code,
        "reason": reason,
        "instruction": instruction,
        "_timing_ms": total_quality_time
    }

# ============================================================================
# CONFIDENCE CALIBRATION & ADAPTIVE MATCHING THRESHOLDS
# ============================================================================

def calibrate_match_confidence(similarity: float) -> float:
    """
    Calibrates raw cosine similarity to a match probability percentage using Sigmoid calibration.
    """
    k = 15.0
    x0 = 0.55
    p = 1.0 / (1.0 + math.exp(-k * (similarity - x0)))
    return round(p * 100.0, 2)

def get_adaptive_max_distance(quality_score: float) -> float:
    """
    Retrieves the adaptive pgvector match distance (1 - similarity threshold) based on image quality.
    """
    if quality_score >= 0.85:
        return 0.32 # High Quality: strict (similarity >= 0.68)
    elif quality_score >= 0.65:
        return 0.38 # Medium Quality: relaxed (similarity >= 0.62)
    else:
        return 0.40 # Low Quality: relaxed (similarity >= 0.60)

# ============================================================================
# AUDIT LOGGING HELPER
# ============================================================================

def log_biometric_access(
    actor_id: str,
    action_type: str,
    status: str,
    target_patient_id: str = None,
    confidence_score: float = None,
    reason: str = None,
    device_id: str = "API",
    gps_coordinates: str = None
):
    try:
        actor_name = "Unknown Actor"
        actor_role = "unknown"
        if actor_id:
            profile_query = supabase.from_("profiles").select("full_name, role").eq("id", actor_id).maybe_single().execute()
            if profile_query.data:
                actor_name = profile_query.data.get("full_name", "Unknown Actor")
                actor_role = profile_query.data.get("role", "unknown")
            else:
                patient_query = supabase.from_("patients").select("id, user_id").eq("id", actor_id).maybe_single().execute()
                if patient_query.data:
                    user_id = patient_query.data.get("user_id")
                    profile_query = supabase.from_("profiles").select("full_name, role").eq("id", user_id).maybe_single().execute()
                    if profile_query.data:
                        actor_name = profile_query.data.get("full_name", "Unknown Actor")
                        actor_role = profile_query.data.get("role", "unknown")

        supabase.from_("biometric_access_logs").insert({
            "actor_id": actor_id,
            "actor_name": actor_name,
            "actor_role": actor_role,
            "action_type": action_type,
            "target_patient_id": target_patient_id,
            "confidence_score": confidence_score,
            "model_version": "ArcFace",
            "status": status,
            "device_id": device_id,
            "gps_coordinates": gps_coordinates,
            "reason": reason
        }).execute()
    except Exception as e:
        logger.error(f"Failed to write audit log: {e}")

# ============================================================================
# DOWNLOAD ROUTINE
# ============================================================================

def download_supabase_file(storage_url: str, dest_suffix: str = ".jpg") -> str:
    from urllib.parse import urlparse, unquote
    import time as _time

    parsed = urlparse(storage_url)
    path_parts = parsed.path.split("/")
    try:
        object_idx = path_parts.index("object")
        bucket = path_parts[object_idx + 2]
        file_path = "/".join(path_parts[object_idx + 3:])
        file_path = unquote(file_path)
    except (ValueError, IndexError):
        raise HTTPException(status_code=400, detail=f"Cannot parse Supabase storage URL: {storage_url[:80]}")

    logger.info(f"Downloading from bucket='{bucket}' path='{file_path}' via service-role client")
    
    last_err = None
    file_bytes = None
    for attempt in range(3):
        try:
            file_bytes = supabase.storage.from_(bucket).download(file_path)
            break
        except Exception as e:
            last_err = e
            logger.warning(f"Storage download attempt {attempt+1}/3 failed for {bucket}/{file_path}: {e}")
            _time.sleep(0.3 * (2 ** attempt))
    else:
        err_msg = f"Failed to retrieve file after retries: {str(last_err)}"
        logger.error(f"[STORAGE_DOWNLOAD_FAILED] bucket={bucket} path={file_path} error={last_err}")
        raise HTTPException(
            status_code=400,
            detail={
                "error_code": "STORAGE_DOWNLOAD_FAILED",
                "message": err_msg,
                "bucket": bucket,
                "path": file_path
            }
        )

    with tempfile.NamedTemporaryFile(delete=False, suffix=dest_suffix) as tmp:
        tmp.write(file_bytes)
        temp_path = tmp.name

    return temp_path

# ============================================================================
# ENDPOINTS
# ============================================================================

class EnrollRequest(BaseModel):
    userId: str
    selfieUrl: Optional[str] = None
    selfieBase64: Optional[str] = None
    poseLabel: str = "neutral"
    enrollment_session_id: Optional[str] = None
    device_info: Optional[str] = None
    camera: Optional[str] = None
    capture_time: Optional[str] = None

class VerifyIDRequest(BaseModel):
    selfieUrl: Optional[str] = None
    selfieBase64: Optional[str] = None
    idDocumentUrl: Optional[str] = None
    idDocumentBase64: Optional[str] = None

@app.get("/")
def read_root():
    return {
        "status": "online",
        "pipeline": "production",
        "model": "ArcFace (512 dims)",
        "detector": "MediaPipe",
        "indexing": "pgvector (HNSW)"
    }

@app.post("/enroll")
async def enroll(
    request: Request,
    payload: EnrollRequest,
    background_tasks: BackgroundTasks,
    authenticated: bool = Depends(verify_token),
    x_actor_id: str = Header(None, alias="X-Actor-Id"),
    x_request_id: str = Header(None, alias="X-Request-Id")
):
    LEFT_RIGHT_YAW_THRESHOLD = 15.0
    UP_DOWN_PITCH_THRESHOLD = 15.0
    start_time = time.time()
    temp_img_path = None
    patient_id = None
    request_id = x_request_id or "unknown"
    try:
        # Pre-fetch existing patient_id for audit logging fallback
        try:
            pat_check = supabase.from_("patients").select("id").eq("user_id", payload.userId).maybe_single().execute()
            if pat_check.data:
                patient_id = pat_check.data["id"]
        except Exception as e:
            logger.warning(f"Could not pre-fetch patient_id for audit logging: {e}")

        logger.info(f"Enrolling pose '{payload.poseLabel}' for user: {payload.userId}")
        
        # Rate Limiting Check
        if not enroll_limiter.is_allowed(payload.userId):
            raise HTTPException(
                status_code=429,
                detail={
                    "error_code": "RATE_LIMITED",
                    "message": "Too many enrollment requests. Please wait before retrying."
                }
            )

        # 1. Load image (Base64 decode if present, else download)
        if payload.selfieBase64:
            try:
                import base64
                b64_data = payload.selfieBase64
                if "," in b64_data:
                    b64_data = b64_data.split(",")[1]
                img_bytes = base64.b64decode(b64_data)
                nparr = np.frombuffer(img_bytes, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "INVALID_IMAGE",
                        "message": f"Failed to decode base64 selfie: {str(e)}"
                    }
                )
        elif payload.selfieUrl:
            temp_img_path = await run_in_threadpool(download_supabase_file, payload.selfieUrl, ".jpg")
            img = cv2.imread(temp_img_path)
        else:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "EMPTY_IMAGE",
                    "message": "Both selfieUrl and selfieBase64 are missing."
                }
            )

        if img is None:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "INVALID_IMAGE",
                    "message": "Loaded image is empty or corrupted."
                }
            )

        # 2. Quality checks & liveness check
        quality_metrics = evaluate_image_quality(img, run_liveness=True)
        pose = quality_metrics["pose"]
        occlusions = quality_metrics["occlusions"]

        # Enrollment Quality Gate (Q >= 0.30)
        if quality_metrics["quality_score"] < 0.30:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "LOW_LIGHT",
                    "message": f"Biometric quality too low ({quality_metrics['quality_score']:.2f}). Try adjusting lighting."
                }
            )

        # Enforce Occlusions Check
        if occlusions["wearing_sunglasses"] or occlusions["wearing_mask"]:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "FACE_OCCLUDED",
                    "message": "Face occluded. Please remove sunglasses/mask to register biometrics."
                }
            )

        # Verify Pose constraints for enrollment
        # Map requested pose labels to roll, yaw, pitch boundaries with relaxed thresholds to prevent false rejections
        pose_label_lower = payload.poseLabel.lower()
        if pose_label_lower == "neutral":
            if abs(pose["yaw"]) > 22 or abs(pose["pitch"]) > 18:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_FAR",
                        "message": "Please look straight at the camera for the Neutral pose."
                    }
                )
        elif "left" in pose_label_lower:
            if pose["yaw"] > -LEFT_RIGHT_YAW_THRESHOLD:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_FAR",
                        "message": "Head not turned left as requested."
                    }
                )
        elif "right" in pose_label_lower:
            if pose["yaw"] < LEFT_RIGHT_YAW_THRESHOLD:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_FAR",
                        "message": "Head not turned right as requested."
                    }
                )
        elif "up" in pose_label_lower:
            if pose["pitch"] > -UP_DOWN_PITCH_THRESHOLD:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_FAR",
                        "message": "Head not tilted up as requested."
                    }
                )
        elif "down" in pose_label_lower:
            if pose["pitch"] < UP_DOWN_PITCH_THRESHOLD:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_FAR",
                        "message": "Head not tilted down as requested."
                    }
                )

        # 3. Generate embedding
        cropped_rgb = (quality_metrics["cropped_face"] * 255).astype(np.uint8)
        cropped_bgr = cv2.cvtColor(cropped_rgb, cv2.COLOR_RGB2BGR)
        quality_metrics.pop("cropped_face", None)

        embeddings = DeepFace.represent(
            img_path=cropped_bgr,
            model_name="ArcFace",
            detector_backend="skip",
            enforce_detection=False
        )

        if not embeddings or len(embeddings) == 0:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "INVALID_IMAGE",
                    "message": "Failed to extract biometric vector."
                }
            )

        embedding_vector = l2_normalize(embeddings[0]["embedding"])

        # 4. Duplicate Enrollment Prevention check (Threshold 0.93 similarity)
        dup_query = supabase.rpc("detect_duplicate_biometrics", {
            "p_query_embedding": embedding_vector,
            "p_threshold": 0.93
        }).execute()

        if dup_query.data:
            existing_pat = dup_query.data[0]
            # If it belongs to a DIFFERENT patient, reject duplicate
            # Fetch existing patient ID if any
            patient_check = supabase.from_("patients").select("id").eq("user_id", payload.userId).maybe_single().execute()
            if patient_check.data and patient_check.data["id"] != existing_pat["patient_id"]:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "error_code": "ALREADY_ENROLLED",
                        "message": "This biometric signature is already enrolled under a different patient profile."
                    }
                )

        # 5. Upsert patient row to prevent race conditions on concurrent enrollment
        upsert_res = supabase.from_("patients").upsert(
            {"user_id": payload.userId},
            on_conflict="user_id"
        ).execute()
        
        if not upsert_res.data:
            raise HTTPException(
                status_code=500,
                detail={
                    "error_code": "SERVER_ERROR",
                    "message": "Failed to initialize patient record."
                }
            )
        patient_id = upsert_res.data[0]["id"]

        # Mark previous session embeddings as archived/inactive if a session ID is provided
        if payload.enrollment_session_id:
            try:
                supabase.from_("patient_embeddings")\
                    .update({"is_active": False})\
                    .eq("patient_id", patient_id)\
                    .neq("enrollment_session_id", payload.enrollment_session_id)\
                    .execute()
            except Exception as archive_err:
                logger.warning(f"Failed to archive prior biometric sessions: {archive_err}")

        # 6. Save vector
        insert_data = {
            "patient_id": patient_id,
            "embedding": embedding_vector,
            "pose_label": payload.poseLabel,
            "quality_score": quality_metrics["quality_score"],
            "model_version": "ArcFace",
            "brightness": quality_metrics.get("brightness", 120.0),
            "sharpness": quality_metrics.get("sharpness", 100.0),
            "capture_time": payload.capture_time or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "device_info": payload.device_info or "Unknown Device",
            "camera": payload.camera or "front",
            "enrollment_session_id": payload.enrollment_session_id,
            "is_active": True
        }
        if "pose" in quality_metrics:
            insert_data["yaw"] = quality_metrics["pose"].get("yaw", 0.0)
            insert_data["pitch"] = quality_metrics["pose"].get("pitch", 0.0)
            insert_data["roll"] = quality_metrics["pose"].get("roll", 0.0)

        try:
            supabase.from_("patient_embeddings").insert(insert_data).execute()
        except Exception as db_err:
            logger.error(f"[SCHEMA DRIFT] patient_embeddings insert missing columns — "
                         f"migration may not be applied: {db_err}")
            insert_data_fallback = {
                "patient_id": patient_id,
                "embedding": embedding_vector,
                "pose_label": payload.poseLabel,
                "quality_score": quality_metrics["quality_score"],
                "model_version": "ArcFace"
            }
            if "pose" in quality_metrics:
                insert_data_fallback["yaw"] = quality_metrics["pose"].get("yaw", 0.0)
                insert_data_fallback["pitch"] = quality_metrics["pose"].get("pitch", 0.0)
                insert_data_fallback["roll"] = quality_metrics["pose"].get("roll", 0.0)
            supabase.from_("patient_embeddings").insert(insert_data_fallback).execute()

        # Update centroid link
        supabase.from_("patients").update({
            "face_scan_url": payload.selfieUrl,
            "face_centroid_version": "ArcFace",
            "updated_at": "now()"
        }).eq("id", patient_id).execute()

        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id or payload.userId,
            action_type="ENROLL",
            status="SUCCESS",
            target_patient_id=patient_id,
            reason=json.dumps({
                "request_id": request_id,
                "pose_label": payload.poseLabel,
                "latency_seconds": time.time() - start_time
            })
        )

        return {
            "success": True,
            "error_code": None,
            "message": "Face enrolled successfully.",
            "request_id": request_id,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "patient_id": patient_id,
            "quality_metrics": quality_metrics,
            "pose_enrolled": payload.poseLabel,
            "latency_seconds": time.time() - start_time
        }

    except HTTPException as he:
        err_code = he.detail.get("error_code") if isinstance(he.detail, dict) else "SERVER_ERROR"
        err_msg = he.detail.get("message") if isinstance(he.detail, dict) else str(he.detail)
        logger.warning(f"[ENROLL FAILED] user={payload.userId} request_id={request_id} "
                       f"error_code={err_code} message={err_msg}")
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id or payload.userId,
            action_type="ENROLL",
            status="FAILURE",
            target_patient_id=patient_id,
            reason=json.dumps({
                "request_id": request_id,
                "error_code": err_code,
                "message": err_msg,
                "latency_seconds": time.time() - start_time
            })
        )
        raise
    except Exception as e:
        logger.error(f"[ENROLL FAILED] user={payload.userId} request_id={request_id} "
                     f"error_code=SERVER_ERROR message={str(e)}")
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id or payload.userId,
            action_type="ENROLL",
            status="FAILURE",
            target_patient_id=patient_id,
            reason=json.dumps({
                "request_id": request_id,
                "error_code": "SERVER_ERROR",
                "message": str(e),
                "latency_seconds": time.time() - start_time
            })
        )
        raise HTTPException(
            status_code=500,
            detail={
                "error_code": "SERVER_ERROR",
                "message": f"Enrollment failed: {str(e)}"
            }
        )
    finally:
        if temp_img_path and os.path.exists(temp_img_path):
            os.remove(temp_img_path)

@app.post("/verify_id")
async def verify_id(
    request: Request,
    payload: VerifyIDRequest,
    background_tasks: BackgroundTasks,
    authenticated: bool = Depends(verify_token),
    x_actor_id: str = Header(None, alias="X-Actor-Id"),
    x_request_id: str = Header(None, alias="X-Request-Id")
):
    temp_selfie_path = None
    temp_id_path = None
    request_id = x_request_id or "unknown"
    start_time = time.time()
    try:
        if x_actor_id and not verify_limiter.is_allowed(x_actor_id):
            raise HTTPException(
                status_code=429,
                detail={
                    "error_code": "RATE_LIMITED",
                    "message": "Too many verification attempts. Please wait."
                }
            )

        # 1. Load Selfie (Base64 decode if present, else download)
        if payload.selfieBase64:
            try:
                import base64
                b64_selfie = payload.selfieBase64
                if "," in b64_selfie:
                    b64_selfie = b64_selfie.split(",")[1]
                img_selfie_bytes = base64.b64decode(b64_selfie)
                nparr_selfie = np.frombuffer(img_selfie_bytes, np.uint8)
                img_selfie = cv2.imdecode(nparr_selfie, cv2.IMREAD_COLOR)
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "INVALID_IMAGE",
                        "message": f"Failed to decode base64 selfie: {str(e)}"
                    }
                )
        elif payload.selfieUrl:
            temp_selfie_path = await run_in_threadpool(download_supabase_file, payload.selfieUrl, ".jpg")
            img_selfie = cv2.imread(temp_selfie_path)
        else:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "EMPTY_IMAGE",
                    "message": "Both selfieUrl and selfieBase64 are missing."
                }
            )

        if img_selfie is None:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "INVALID_IMAGE",
                    "message": "Selfie image is corrupted."
                }
            )
        h1, w1 = img_selfie.shape[:2]
        if h1 < 320 or w1 < 320:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "FACE_TOO_SMALL",
                    "message": "Selfie image resolution too low."
                }
            )
        img_selfie_resized = resize_to_consistent_size(img_selfie, max_dim=640)
        mp_selfie = analyze_face_with_mediapipe(img_selfie_resized)
        face_selfie = detect_and_align_face(img_selfie_resized, is_id_doc=False, run_liveness=True, mp_result=mp_selfie)
        cropped_selfie_rgb = (face_selfie["face"] * 255).astype(np.uint8)
        cropped_selfie_bgr = cv2.cvtColor(cropped_selfie_rgb, cv2.COLOR_RGB2BGR)

        # 2. Load ID Document (Base64 decode if present, else download)
        if payload.idDocumentBase64:
            try:
                import base64
                b64_id = payload.idDocumentBase64
                if "," in b64_id:
                    b64_id = b64_id.split(",")[1]
                img_id_bytes = base64.b64decode(b64_id)
                nparr_id = np.frombuffer(img_id_bytes, np.uint8)
                img_id = cv2.imdecode(nparr_id, cv2.IMREAD_COLOR)
            except Exception as e:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "INVALID_IMAGE",
                        "message": f"Failed to decode base64 ID document: {str(e)}"
                    }
                )
        elif payload.idDocumentUrl:
            temp_id_path = await run_in_threadpool(download_supabase_file, payload.idDocumentUrl, ".jpg")
            img_id = cv2.imread(temp_id_path)
        else:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "EMPTY_IMAGE",
                    "message": "Both idDocumentUrl and idDocumentBase64 are missing."
                }
            )

        if img_id is None:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "INVALID_IMAGE",
                    "message": "ID document is corrupted."
                }
            )
        h2, w2 = img_id.shape[:2]
        if h2 < 320 or w2 < 320:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "FACE_TOO_SMALL",
                    "message": "ID image resolution too low."
                }
            )
        img_id_resized = resize_to_consistent_size(img_id, max_dim=640)
        face_id = detect_and_align_face(img_id_resized, is_id_doc=True, run_liveness=False)
        cropped_id_rgb = (face_id["face"] * 255).astype(np.uint8)
        cropped_id_bgr = cv2.cvtColor(cropped_id_rgb, cv2.COLOR_RGB2BGR)

        result = DeepFace.verify(
            img1_path=cropped_selfie_bgr,
            img2_path=cropped_id_bgr,
            model_name="ArcFace",
            detector_backend="skip",
            enforce_detection=False
        )
        
        similarity = 1.0 - float(result["distance"])
        verified = bool(result["verified"])

        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="VERIFY_ID",
            status="SUCCESS" if verified else "FAILURE",
            confidence_score=similarity,
            reason=json.dumps({
                "request_id": request_id,
                "verified": verified,
                "latency_seconds": time.time() - start_time
            })
        )

        return {
            "success": True,
            "error_code": None,
            "message": "ID verification completed.",
            "request_id": request_id,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "verified": verified,
            "distance": float(result["distance"]),
            "similarity": float(similarity)
        }
    except HTTPException as he:
        err_code = he.detail.get("error_code") if isinstance(he.detail, dict) else "SERVER_ERROR"
        err_msg = he.detail.get("message") if isinstance(he.detail, dict) else str(he.detail)
        logger.warning(f"[VERIFY_ID FAILED] actor={x_actor_id} request_id={request_id} "
                       f"error_code={err_code} message={err_msg}")
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="VERIFY_ID",
            status="FAILURE",
            reason=json.dumps({
                "request_id": request_id,
                "error_code": err_code,
                "message": err_msg,
                "latency_seconds": time.time() - start_time
            })
        )
        raise
    except Exception as e:
        logger.error(f"[VERIFY_ID FAILED] actor={x_actor_id} request_id={request_id} "
                     f"error_code=SERVER_ERROR message={str(e)}")
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="VERIFY_ID",
            status="FAILURE",
            reason=json.dumps({
                "request_id": request_id,
                "error_code": "SERVER_ERROR",
                "message": str(e),
                "latency_seconds": time.time() - start_time
            })
        )
        raise HTTPException(
            status_code=500,
            detail={
                "error_code": "SERVER_ERROR",
                "message": f"Comparison failed: {str(e)}"
            }
        )
    finally:
        if temp_selfie_path and os.path.exists(temp_selfie_path):
            os.remove(temp_selfie_path)
        if temp_id_path and os.path.exists(temp_id_path):
            os.remove(temp_id_path)

@app.post("/identify")
async def identify(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    authenticated: bool = Depends(verify_token),
    x_actor_id: str = Header(None, alias="X-Actor-Id"),
    x_request_id: str = Header(None, alias="X-Request-Id")
):
    start_time = time.time()
    request_id = x_request_id or "unknown"
    
    # Rate Limiting
    client_ip = request.client.host if request.client else "unknown"
    if not identify_limiter.is_allowed(client_ip):
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="IDENTIFY",
            status="DENIED",
            reason=json.dumps({
                "request_id": request_id,
                "error_code": "RATE_LIMITED",
                "message": "Rate limit exceeded on /identify endpoint."
            })
        )
        raise HTTPException(
            status_code=429,
            detail={
                "error_code": "RATE_LIMITED",
                "message": "Too many identification attempts. Please wait."
            }
        )

    # 1. Read and process image file


    try:
        # Read bytes
        file_bytes = await file.read()
        if not file_bytes:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "EMPTY_IMAGE",
                    "message": "Uploaded file is empty."
                }
            )

        # Decode image
        nparr = np.frombuffer(file_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "INVALID_IMAGE",
                    "message": "Uploaded file is not a valid image."
                }
            )

        # 2. Quality gate and liveness verification
        quality_metrics = evaluate_image_quality(img, run_liveness=True)
        occlusions = quality_metrics["occlusions"]
        quality_score = quality_metrics["quality_score"]

        # Keep quality_score log as a non-blocking diagnostic
        logger.info(f"[IDENTIFY DIAGNOSTIC] raw quality_score={quality_score:.4f}")

        # Quality component-based gates matching /enroll pattern with safe mock fallbacks
        brightness = quality_metrics.get("brightness", 120.0)
        sharpness = quality_metrics.get("sharpness", 100.0)

        if brightness < 45 or brightness > 220:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "LOW_LIGHT" if brightness < 45 else "OVER_EXPOSED",
                    "message": f"Lighting not suitable for scan (brightness={brightness:.1f}). "
                               f"Move to an evenly lit area."
                }
            )

        if sharpness < 55.0:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "IMAGE_BLUR",
                    "message": f"Scan not sharp enough (sharpness={sharpness:.1f}). "
                               f"Hold the camera steady."
                }
            )

        if occlusions["wearing_mask"] or occlusions["wearing_sunglasses"]:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "FACE_OCCLUDED",
                    "message": "Face occluded. Please remove glasses/mask to verify identity."
                }
            )
        # Enforce face size constraint to prevent false rejections due to distance/low resolution
        if not quality_metrics.get("size_good", True):
            face_percentage = quality_metrics.get("face_percentage", 100.0)
            if face_percentage < 18.0:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_SMALL",
                        "message": f"Face too far (percentage in frame {face_percentage:.1f}% is below 18%). Move closer to the camera."
                    }
                )
            elif face_percentage > 40.0:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "FACE_TOO_LARGE",
                        "message": f"Face too close (percentage in frame {face_percentage:.1f}% exceeds 40%). Move back slightly."
                    }
                )
        cropped_rgb = (quality_metrics["cropped_face"] * 255).astype(np.uint8)
        cropped_bgr = cv2.cvtColor(cropped_rgb, cv2.COLOR_RGB2BGR)
        quality_metrics.pop("cropped_face", None)

        # 3. Generate query vector
        embeddings = DeepFace.represent(
            img_path=cropped_bgr,
            model_name="ArcFace",
            detector_backend="skip",
            enforce_detection=False
        )
        if not embeddings or len(embeddings) == 0:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "INVALID_IMAGE",
                    "message": "Failed to build signature from scan."
                }
            )
        query_vector = l2_normalize(embeddings[0]["embedding"])

        # Check if the query is an angled/profile scan to enforce stricter thresholds
        pose = quality_metrics.get("pose", {"yaw": 0.0, "pitch": 0.0, "roll": 0.0})
        yaw = abs(pose.get("yaw", 0.0))
        pitch = abs(pose.get("pitch", 0.0))
        is_profile_scan = yaw > 15.0 or pitch > 12.0

        # 4. Adaptive matching threshold configuration
        adaptive_max_distance = get_adaptive_max_distance(quality_score)
        # 5. Stage 1: Vector similarity search (HNSW index)
        # We query the database with a relaxed max_distance of 0.40 to guarantee candidate retrieval under
        # pitch/yaw tilts. The strict quality-based threshold (adaptive_max_distance) is enforced in Python (Stage 2).
        rpc_res = supabase.rpc("match_patient_by_face_consensus", {
            "query_embedding": query_vector,
            "max_distance": 0.40,
            "match_limit": 5,
            "consensus_strategy": "max"
        }).execute()

        match_candidates = rpc_res.data
        if not match_candidates or len(match_candidates) == 0:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "NO_MATCH_FOUND",
                    "message": "No matching profile found."
                }
            )

        # 6. Stage 2: Verification and Multiple Pose Consensus Check in Python
        raw_matches = []
        for cand in match_candidates:
            # Query all enrolled active poses for this candidate patient
            poses_res = supabase.from_("patient_embeddings").select("embedding, pose_label, quality_score").eq("patient_id", cand["patient_id"]).eq("is_active", True).execute()
            if not poses_res.data:
                continue

            # ─── CONSENSUS CALCULATION: COGS & METRICS ───────────────────────
            # Calculate individual cosine similarities for each of the enrolled active poses.
            # Since ArcFace vectors are L2-normalized, the cosine similarity is simply the
            # dot product of the query vector and the enrolled vector: S = u . v
            pose_similarities = []
            weights = []
            for p_rec in poses_res.data:
                v_raw = p_rec["embedding"]
                if isinstance(v_raw, str):
                    try:
                        v_raw = json.loads(v_raw)
                    except Exception:
                        v_raw = [float(x) for x in v_raw.strip('[]').split(',')]
                v_enrolled = np.array(v_raw)
                sim = np.dot(query_vector, v_enrolled)
                pose_similarities.append(sim)
                # Weight matches by the image quality score to penalize blurry/dark captures
                weights.append(p_rec.get("quality_score") or 1.0)
            
            if not pose_similarities:
                continue
                
            # ─── CONSENSUS METRIC FORMULATION ───────────────────────────────
            # max_sim: Best single pose match (resilient to pose variation)
            # mean_sim: Average match across all poses
            # weighted_sim: Average match weighted by registration quality
            max_sim = max(pose_similarities)
            mean_sim = sum(pose_similarities) / len(pose_similarities)
            weighted_sim = sum(s * w for s, w in zip(pose_similarities, weights)) / sum(weights)

            raw_matches.append({
                "patient_id": cand["patient_id"],
                "qr_code_id": cand["qr_code_id"],
                "full_name": cand["full_name"],
                "pose_matched": cand["pose_label"],
                "similarity": max_sim,
                "consensus": {
                    "max_similarity": float(max_sim),
                    "mean_similarity": float(mean_sim),
                    "weighted_similarity": float(weighted_sim)
                }
            })

        if not raw_matches:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "NO_MATCH_FOUND",
                    "message": "No matching profile found."
                }
            )

        # Sort candidate matches by similarity to identify the top match
        raw_matches.sort(key=lambda x: x["similarity"], reverse=True)
        best_match = raw_matches[0]

        # Enforce dynamic quality-based similarity thresholds on the best match:
        # S >= (1.0 - adaptive_max_distance)
        min_similarity_gate = 1.0 - adaptive_max_distance
        if best_match["similarity"] < min_similarity_gate:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "NO_MATCH_FOUND",
                    "message": "Biometric verification failed (below threshold)."
                }
            )

        # Enforce baseline consensus check to prevent single-pose anomaly false positives
        if best_match["consensus"]["mean_similarity"] < 0.34:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "NO_MATCH_FOUND",
                    "message": "Biometric verification failed (consensus threshold not met)."
                }
            )

        # ─── AMBIGUITY CHECK (MARGIN GUARD) ──────────────────────────────
        # To prevent misidentification in crowded databases, the difference in
        # similarity between the top candidate and the runner-up must exceed a
        # safe margin threshold of 0.03. If the margin is smaller, the match is
        # marked as ambiguous.
        margin = 0.0
        if len(raw_matches) > 1:
            second_match = raw_matches[1]
            margin = best_match["similarity"] - second_match["similarity"]
            if margin < 0.03:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "error_code": "LOW_CONFIDENCE",
                        "message": "Ambiguous match. Multiple profiles appear similarly close. Try scanning again."
                    }
                )

        # 8. Calibrated Confidence mapping
        confidence = calibrate_match_confidence(best_match["similarity"])
        logger.info(
            f"[MATCH_DEBUG] patient_id={best_match['patient_id']} raw_similarity={best_match['similarity']:.4f} "
            f"calibrated_confidence={confidence:.1f} quality_tier_max_distance={adaptive_max_distance}"
        )
        if confidence < 60.0:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "LOW_CONFIDENCE",
                    "message": "Match confidence too low to verify identity. Please verify lighting and scan again."
                }
            )

        # Construct result
        res_payload = {
            "success": True,
            "error_code": None,
            "message": "Patient identified successfully.",
            "request_id": request_id,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "patient_id": best_match["patient_id"],
            "qr_code_id": best_match["qr_code_id"],
            "full_name": best_match["full_name"],
            "pose_matched": best_match["pose_matched"],
            "similarity": best_match["similarity"],
            "confidence": confidence,
            "match_margin": margin,
            "quality_metrics": quality_metrics,
            "consensus": best_match["consensus"]
        }


        # Audit logging
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="IDENTIFY",
            status="SUCCESS",
            target_patient_id=best_match["patient_id"],
            confidence_score=best_match["similarity"],
            reason=json.dumps({
                "request_id": request_id,
                "error_code": None,
                "message": "Patient identified successfully.",
                "match_margin": margin,
                "latency_seconds": time.time() - start_time,
                "quality_score": quality_score,
                "consensus": best_match["consensus"]
            })
        )

        return res_payload

    except HTTPException as he:
        err_code = he.detail.get("error_code") if isinstance(he.detail, dict) else "SERVER_ERROR"
        err_msg = he.detail.get("message") if isinstance(he.detail, dict) else str(he.detail)
        logger.warning(f"[IDENTIFY FAILED] actor={x_actor_id} request_id={request_id} "
                       f"error_code={err_code} message={err_msg}")
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="IDENTIFY",
            status="FAILURE" if he.status_code == 404 or he.status_code == 400 else "DENIED",
            reason=json.dumps({
                "request_id": request_id,
                "error_code": err_code,
                "message": err_msg,
                "latency_seconds": time.time() - start_time
            })
        )
        raise
    except Exception as e:
        logger.error(f"[IDENTIFY FAILED] actor={x_actor_id} request_id={request_id} "
                     f"error_code=SERVER_ERROR message={str(e)}")
        background_tasks.add_task(
            log_biometric_access,
            actor_id=x_actor_id,
            action_type="IDENTIFY",
            status="FAILURE",
            reason=json.dumps({
                "request_id": request_id,
                "error_code": "SERVER_ERROR",
                "message": str(e),
                "latency_seconds": time.time() - start_time
            })
        )
        raise HTTPException(
            status_code=500,
            detail={
                "error_code": "SERVER_ERROR",
                "message": str(e)
            }
        )

@app.post("/analyze_frame")
async def analyze_frame(
    file: UploadFile = File(...),
    target_pose: Optional[str] = Form(None)
):
    start_time = time.time()
    try:
        contents = await file.read()
        read_time = (time.time() - start_time) * 1000.0
        
        start_decode = time.time()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        decode_time = (time.time() - start_decode) * 1000.0
        
        if img is None:
            return {"success": False, "message": "Invalid image"}
        
        quality_metrics = await run_in_threadpool(evaluate_image_quality, img, False, False, target_pose)
        quality_metrics.pop("cropped_face", None)
        
        total_time = (time.time() - start_time) * 1000.0
        logger.info(
            f"Frame Process Timing -> Total: {total_time:.1f}ms | "
            f"Read: {read_time:.1f}ms | Decode: {decode_time:.1f}ms | "
            f"Quality/Pose: {quality_metrics.get('_timing_ms', 0.0):.1f}ms"
        )
        quality_metrics.pop("_timing_ms", None)
        
        if not quality_metrics.get("capture_eligible", False):
            guidance = quality_metrics.get("instruction") or quality_metrics.get("guidance", "Keep your face steady")
            error_code = quality_metrics.get("error_code")
            
            if not error_code:
                error_code = "VALIDATION_FAILED"
                if "mask" in guidance.lower() or "sunglasses" in guidance.lower():
                    error_code = "FACE_OCCLUDED"
                elif "light" in guidance.lower() or "brighter" in guidance.lower() or "exposed" in guidance.lower():
                    error_code = "POOR_LIGHTING"
                elif "blurry" in guidance.lower() or "still" in guidance.lower():
                    error_code = "IMAGE_BLUR"
                elif "center" in guidance.lower():
                    error_code = "FACE_NOT_CENTERED"
                elif "closer" in guidance.lower():
                    error_code = "FACE_TOO_SMALL"
                elif "back" in guidance.lower():
                    error_code = "FACE_TOO_LARGE"
                elif "head" in guidance.lower() or "chin" in guidance.lower() or "turn" in guidance.lower() or "tilt" in guidance.lower():
                    error_code = "WRONG_POSE"
                    
            reason = quality_metrics.get("reason", "Validation failed")
            
            return {
                "success": False,
                "error_code": error_code,
                "message": guidance,
                "instruction": guidance,
                "reason": reason,
                "capture_score": quality_metrics.get("capture_score", 0.0),
                "centered": quality_metrics.get("centered", False),
                "lighting_good": quality_metrics.get("lighting_good", False),
                "sharpness_good": quality_metrics.get("sharpness_good", False),
                "pose_valid": quality_metrics.get("pose_valid", False),
                "pose": quality_metrics.get("pose", {"yaw": 0.0, "pitch": 0.0, "roll": 0.0}),
                "sharpness": quality_metrics.get("sharpness", 0.0),
                "brightness": quality_metrics.get("brightness", 0.0),
                "face_percentage_in_frame": quality_metrics.get("face_percentage_in_frame", 0.0),
                "face_confidence": quality_metrics.get("face_confidence", 0.0),
                "pose_confidence": quality_metrics.get("pose_confidence", 0.0),
                "capture_eligible": False
            }

        return {
            "success": True,
            "quality_score": float(quality_metrics["quality_score"]),
            "sharpness": float(quality_metrics["sharpness"]),
            "brightness": float(quality_metrics["brightness"]),
            "pose": quality_metrics["pose"],
            "occlusions": quality_metrics["occlusions"],
            "eyes_visible": bool(quality_metrics["eyes_visible"]),
            "face_percentage_in_frame": float(quality_metrics["face_percentage_in_frame"]),
            "face_confidence": float(quality_metrics["face_confidence"]),
            "pose_confidence": float(quality_metrics["pose_confidence"]),
            "capture_score": float(quality_metrics.get("capture_score", 100.0)),
            "centered": quality_metrics.get("centered", True),
            "lighting_good": quality_metrics.get("lighting_good", True),
            "sharpness_good": quality_metrics.get("sharpness_good", True),
            "pose_valid": quality_metrics.get("pose_valid", True),
            "instruction": quality_metrics.get("instruction", "Hold still"),
            "guidance": quality_metrics["guidance"],
            "capture_eligible": bool(quality_metrics["capture_eligible"])
        }
    except HTTPException as he:
        return {
            "success": False,
            "error_code": he.detail.get("error_code") if isinstance(he.detail, dict) else "VALIDATION_ERROR",
            "message": he.detail.get("message") if isinstance(he.detail, dict) else str(he.detail)
        }
    except Exception as e:
        return {"success": False, "message": str(e)}

@app.get("/diagnostics/mediapipe")
async def diagnostics_mediapipe():
    import sys
    import platform
    import time
    
    start_init = time.time()
    solutions_available = False
    facemesh_initialized = False
    mp_version = "unknown"
    mp_file = "unknown"
    
    try:
        import mediapipe as mp
        mp_version = getattr(mp, "__version__", "unknown")
        mp_file = getattr(mp, "__file__", "unknown")
        solutions_available = hasattr(mp, "solutions")
        if solutions_available:
            fm = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.5
            )
            facemesh_initialized = fm is not None
    except Exception as e:
        logger.exception("Diagnostics MediaPipe check failed")
        
    init_time = (time.time() - start_init) * 1000.0
    
    return {
        "python_version": sys.version,
        "mediapipe_version": mp_version,
        "import_path": mp_file,
        "solutions_available": solutions_available,
        "facemesh_initialized": facemesh_initialized,
        "gpu_available": False,
        "cpu_available": True,
        "initialization_time_ms": init_time
    }

def l2_normalize(vector: List[float]) -> List[float]:
    arr = np.array(vector)
    norm = np.linalg.norm(arr)
    if norm == 0:
        return vector
    return (arr / norm).tolist()
