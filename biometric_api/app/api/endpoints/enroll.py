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
from app.schemas.biometric import EnrollRequest, CompleteEnrollRequest, CleanupEnrollRequest

router = APIRouter()

@router.post("/enroll")
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
            pat_check = main.supabase.from_("patients").select("id").eq("user_id", payload.userId).maybe_single().execute()
            if pat_check.data:
                patient_id = pat_check.data["id"]
        except Exception as e:
            main.logger.warning(f"Could not pre-fetch patient_id for audit logging: {e}")

        main.logger.info(f"Enrolling pose '{payload.poseLabel}' for user: {payload.userId}")
        
        # Rate Limiting Check
        if not main.enroll_limiter.is_allowed(payload.userId):
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
            temp_img_path = await run_in_threadpool(main.download_supabase_file, payload.selfieUrl, ".jpg")
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
        quality_metrics = main.evaluate_image_quality(img, run_liveness=True)
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

        embeddings = main.DeepFace.represent(
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

        embedding_vector = main.l2_normalize(embeddings[0]["embedding"])

        # 4. Duplicate Enrollment Prevention check (Threshold 0.93 similarity)
        dup_query = main.supabase.rpc("detect_duplicate_biometrics", {
            "p_query_embedding": embedding_vector,
            "p_threshold": 0.93
        }).execute()

        if dup_query.data:
            existing_pat = dup_query.data[0]
            existing_id = existing_pat.get("patient_id") or existing_pat.get("identity_id")
            patient_check = main.supabase.from_("patients").select("id").eq("user_id", payload.userId).maybe_single().execute()
            if patient_check.data and patient_check.data["id"] != existing_id:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "error_code": "ALREADY_ENROLLED",
                        "message": "This biometric signature is already enrolled under a different patient profile."
                    }
                )

        # 5. Upsert patient row to prevent race conditions on concurrent enrollment
        upsert_res = main.supabase.from_("patients").upsert(
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
                main.supabase.from_("patient_embeddings")\
                    .update({"is_active": False})\
                    .eq("patient_id", patient_id)\
                    .neq("enrollment_session_id", payload.enrollment_session_id)\
                    .execute()
            except Exception as archive_err:
                main.logger.warning(f"Failed to archive prior biometric sessions: {archive_err}")

        # 6. Save vector (is_active set to False; activated atomically at /enroll/complete)
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
            "is_active": False
        }
        if "pose" in quality_metrics:
            insert_data["yaw"] = quality_metrics["pose"].get("yaw", 0.0)
            insert_data["pitch"] = quality_metrics["pose"].get("pitch", 0.0)
            insert_data["roll"] = quality_metrics["pose"].get("roll", 0.0)

        try:
            main.supabase.from_("patient_embeddings").insert(insert_data).execute()
        except Exception as db_err:
            main.logger.error(f"[SCHEMA DRIFT] patient_embeddings insert missing columns — "
                         f"migration may not be applied: {db_err}")
            insert_data_fallback = {
                "patient_id": patient_id,
                "embedding": embedding_vector,
                "pose_label": payload.poseLabel,
                "quality_score": quality_metrics["quality_score"],
                "model_version": "ArcFace",
                "is_active": False
            }
            if "pose" in quality_metrics:
                insert_data_fallback["yaw"] = quality_metrics["pose"].get("yaw", 0.0)
                insert_data_fallback["pitch"] = quality_metrics["pose"].get("pitch", 0.0)
                insert_data_fallback["roll"] = quality_metrics["pose"].get("roll", 0.0)
            main.supabase.from_("patient_embeddings").insert(insert_data_fallback).execute()

        # Update centroid link
        main.supabase.from_("patients").update({
            "face_scan_url": payload.selfieUrl,
            "face_centroid_version": "ArcFace",
            "updated_at": "now()"
        }).eq("id", patient_id).execute()

        background_tasks.add_task(
            main.log_biometric_access,
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
        main.logger.warning(f"[ENROLL FAILED] user={payload.userId} request_id={request_id} "
                       f"error_code={err_code} message={err_msg}")
        background_tasks.add_task(
            main.log_biometric_access,
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
        main.logger.error(f"[ENROLL FAILED] user={payload.userId} request_id={request_id} "
                     f"error_code=SERVER_ERROR message={str(e)}")
        background_tasks.add_task(
            main.log_biometric_access,
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

@router.post("/enroll/complete")
async def enroll_complete(
    payload: CompleteEnrollRequest,
    authenticated: bool = Depends(verify_token)
):
    try:
        pat_check = main.supabase.from_("patients").select("id").eq("user_id", payload.userId).maybe_single().execute()
        if not pat_check.data:
            raise HTTPException(status_code=404, detail={
                "error_code": "NOT_FOUND",
                "message": "Patient record not found."
            })
        patient_id = pat_check.data["id"]

        embeddings_check = main.supabase.from_("patient_embeddings")\
            .select("id")\
            .eq("patient_id", patient_id)\
            .eq("enrollment_session_id", payload.enrollment_session_id)\
            .execute()
        
        if not embeddings_check.data:
            raise HTTPException(status_code=400, detail={
                "error_code": "INVALID_SESSION",
                "message": "No embeddings found for this session."
            })

        main.supabase.from_("patients").update({
            "biometric_status": "completed",
            "updated_at": "now()"
        }).eq("id", patient_id).execute()

        main.supabase.from_("patient_embeddings")\
            .update({"is_active": False})\
            .eq("patient_id", patient_id)\
            .neq("enrollment_session_id", payload.enrollment_session_id)\
            .execute()

        main.supabase.from_("patient_embeddings")\
            .update({"is_active": True})\
            .eq("patient_id", patient_id)\
            .eq("enrollment_session_id", payload.enrollment_session_id)\
            .execute()

        return {
            "success": True,
            "message": "Biometric enrollment completed and activated."
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        main.logger.error(f"[ENROLL COMPLETE ERROR] userId={payload.userId}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={
            "error_code": "SERVER_ERROR",
            "message": str(e)
        })

@router.post("/enroll/cleanup")
async def enroll_cleanup(
    payload: CleanupEnrollRequest,
    authenticated: bool = Depends(verify_token)
):
    try:
        pat_check = main.supabase.from_("patients").select("id, biometric_status").eq("user_id", payload.userId).maybe_single().execute()
        if not pat_check.data:
            return {"success": True, "message": "No patient record to clean up."}
        patient_id = pat_check.data["id"]
        status = pat_check.data["biometric_status"]

        embeddings = main.supabase.from_("patient_embeddings")\
            .select("id, pose_label")\
            .eq("patient_id", patient_id)\
            .eq("enrollment_session_id", payload.enrollment_session_id)\
            .execute()

        if embeddings.data:
            main.supabase.from_("patient_embeddings")\
                .delete()\
                .eq("patient_id", patient_id)\
                .eq("enrollment_session_id", payload.enrollment_session_id)\
                .execute()

            try:
                storage_files = main.supabase.storage.from_("kyc-documents").list(payload.userId)
                if storage_files:
                    to_delete = []
                    pose_labels = [emb["pose_label"] for emb in embeddings.data]
                    for f in storage_files:
                        name = f.get("name")
                        if name and any(f"selfie_{pose}" in name for pose in pose_labels):
                            to_delete.append(f"{payload.userId}/{name}")
                    if to_delete:
                        main.supabase.storage.from_("kyc-documents").remove(to_delete)
            except Exception as st_err:
                main.logger.warning(f"Failed to delete selfie files from storage during cleanup: {st_err}")

        remaining = main.supabase.from_("patient_embeddings")\
            .select("id")\
            .eq("patient_id", patient_id)\
            .execute()
        
        if not remaining.data and status == "incomplete":
            main.supabase.from_("patients").delete().eq("id", patient_id).execute()
            main.logger.info(f"Cleaned up orphaned incomplete patients record for user {payload.userId}")

        return {
            "success": True,
            "message": "Biometric enrollment session cleaned up."
        }
    except Exception as e:
        main.logger.error(f"[ENROLL CLEANUP ERROR] userId={payload.userId}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail={
            "error_code": "SERVER_ERROR",
            "message": str(e)
        })
