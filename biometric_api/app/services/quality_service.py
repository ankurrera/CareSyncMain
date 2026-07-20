import time
import cv2
import numpy as np
from typing import Dict, Any, Optional
from fastapi import HTTPException
from app.core.logging import logger
from app.services.mediapipe_service import analyze_face_with_mediapipe
from app.services.deepface_service import detect_and_align_face

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

    # ── POSE CONFIDENCE & DYNAMIC GUIDANCE ──────────────────
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
        occlusion_free = not (occlusions.get("wearing_sunglasses", False) or occlusions.get("wearing_mask", False))
        occlusion_score = 1.0 if occlusion_free else 0.0
        
        # 5. Face Size Calculations
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
        
        # Rule-based Capture Eligibility check
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

        pose_confidence = capture_score
        guidance = instruction

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
        "size_good": bool(size_good),
        "face_percentage": round(float(face_percentage), 2),
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
