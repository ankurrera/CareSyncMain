import time
import numpy as np
import cv2
from typing import Optional
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.concurrency import run_in_threadpool

import main

router = APIRouter()

@router.post("/analyze_frame")
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
        
        quality_metrics = await run_in_threadpool(main.evaluate_image_quality, img, False, False, target_pose)
        quality_metrics.pop("cropped_face", None)
        
        total_time = (time.time() - start_time) * 1000.0
        main.logger.info(
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
