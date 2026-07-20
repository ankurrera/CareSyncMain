import cv2
import numpy as np
from typing import Dict, Any, Optional
import mediapipe as mp
from app.core.logging import logger

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

def align_and_crop_with_mediapipe(img: np.ndarray, mp_result: Dict[str, Any]) -> Dict[str, Any]:
    h, w = img.shape[:2]
    landmarks = mp_result["landmarks"]
    
    # Eye centers as midpoint of outer and inner corners
    left_eye_x = (landmarks[33].x + landmarks[133].x) / 2.0 * w
    left_eye_y = (landmarks[33].y + landmarks[133].y) / 2.0 * h
    
    right_eye_x = (landmarks[263].x + landmarks[362].x) / 2.0 * w
    right_eye_y = (landmarks[263].y + landmarks[362].y) / 2.0 * h
    
    nose_x = landmarks[1].x * w
    nose_y = landmarks[1].y * h
    
    mouth_left_x = landmarks[61].x * w
    mouth_left_y = landmarks[61].y * h
    
    mouth_right_x = landmarks[291].x * w
    mouth_right_y = landmarks[291].y * h
    
    src_pts = np.array([
        [left_eye_x, left_eye_y],
        [right_eye_x, right_eye_y],
        [(mouth_left_x + mouth_right_x) / 2.0, (mouth_left_y + mouth_right_y) / 2.0]
    ], dtype=np.float32)
    
    ref_pts = np.array([
        [30.2946, 51.6963],
        [81.7054, 51.6963],
        [56.0000, 92.2041]
    ], dtype=np.float32)
    
    M, _ = cv2.estimateAffinePartial2D(src_pts, ref_pts)
    
    if M is not None:
        cropped = cv2.warpAffine(img, M, (112, 112))
    else:
        logger.warning("Similarity transform estimation failed. Falling back to simple eye-based crop.")
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
        
    cropped_rgb = cv2.cvtColor(cropped, cv2.COLOR_BGR2RGB)
    cropped_normalized = cropped_rgb.astype(np.float32) / 255.0
    
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
