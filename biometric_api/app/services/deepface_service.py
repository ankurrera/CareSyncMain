import cv2
import numpy as np
from typing import Dict, Any, Optional
from fastapi import HTTPException
from deepface import DeepFace
from app.core.logging import logger
from app.services.mediapipe_service import align_and_crop_with_mediapipe

# Check if PyTorch (Anti-Spoofing Dependency) is available
try:
    import torch
    torch.set_num_threads(1)
    has_torch = True
except ImportError:
    has_torch = False
    logger.error("Torch is not installed. Face anti-spoofing (liveness check) will be bypassed.")

def detect_and_align_face(img: np.ndarray, is_id_doc: bool = False, run_liveness: bool = False, mp_result: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    # If pre-computed MediaPipe landmarks exist and it is not an ID document, crop/align in python directly (~2ms)
    if mp_result is not None and not is_id_doc:
        try:
            logger.info("Aligning and cropping face using pre-computed MediaPipe FaceMesh landmarks.")
            face = align_and_crop_with_mediapipe(img, mp_result)
            
            # Check liveness if requested using skip detector backend (fast)
            if run_liveness and has_torch:
                logger.info("Running liveness check on the MediaPipe face with padded context.")
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
            raise
        except Exception as e:
            last_exc = e
            logger.warning(f"Backend '{backend}' failed during extraction: {e}")
            continue

    raise HTTPException(
        status_code=400,
        detail={
            "error_code": "NO_FACE_DETECTED",
            "message": "No face detected. Please ensure a clear face is visible." if is_id_doc else "No face detected. Please position the camera directly in front of the face."
        }
    )
