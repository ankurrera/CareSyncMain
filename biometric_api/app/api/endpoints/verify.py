import os
import time
import json
import base64
import cv2
import numpy as np
from fastapi import APIRouter, Request, Depends, Header, BackgroundTasks, HTTPException
from fastapi.concurrency import run_in_threadpool

import main
from app.core.security import verify_token
from app.schemas.biometric import VerifyIDRequest

router = APIRouter()

@router.post("/verify_id")
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
        if x_actor_id and not main.verify_limiter.is_allowed(x_actor_id):
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
            temp_selfie_path = await run_in_threadpool(main.download_supabase_file, payload.selfieUrl, ".jpg")
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
        img_selfie_resized = main.resize_to_consistent_size(img_selfie, max_dim=640)
        mp_selfie = main.analyze_face_with_mediapipe(img_selfie_resized)
        face_selfie = main.detect_and_align_face(img_selfie_resized, is_id_doc=False, run_liveness=True, mp_result=mp_selfie)
        cropped_selfie_rgb = (face_selfie["face"] * 255).astype(np.uint8)
        cropped_selfie_bgr = cv2.cvtColor(cropped_selfie_rgb, cv2.COLOR_RGB2BGR)

        # 2. Load ID Document (Base64 decode if present, else download)
        if payload.idDocumentBase64:
            try:
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
            temp_id_path = await run_in_threadpool(main.download_supabase_file, payload.idDocumentUrl, ".jpg")
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
        img_id_resized = main.resize_to_consistent_size(img_id, max_dim=640)
        face_id = main.detect_and_align_face(img_id_resized, is_id_doc=True, run_liveness=False)
        cropped_id_rgb = (face_id["face"] * 255).astype(np.uint8)
        cropped_id_bgr = cv2.cvtColor(cropped_id_rgb, cv2.COLOR_RGB2BGR)

        result = main.DeepFace.verify(
            img1_path=cropped_selfie_bgr,
            img2_path=cropped_id_bgr,
            model_name="ArcFace",
            detector_backend="skip",
            enforce_detection=False
        )
        
        similarity = 1.0 - float(result["distance"])
        verified = bool(result["verified"])

        background_tasks.add_task(
            main.log_biometric_access,
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
        main.logger.warning(f"[VERIFY_ID FAILED] actor={x_actor_id} request_id={request_id} "
                       f"error_code={err_code} message={err_msg}")
        background_tasks.add_task(
            main.log_biometric_access,
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
        main.logger.error(f"[VERIFY_ID FAILED] actor={x_actor_id} request_id={request_id} "
                     f"error_code=SERVER_ERROR message={str(e)}")
        background_tasks.add_task(
            main.log_biometric_access,
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
