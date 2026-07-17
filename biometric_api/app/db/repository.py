import tempfile
import time
from urllib.parse import urlparse, unquote
from fastapi import HTTPException
from app.core.logging import logger
from app.db.supabase import supabase

def download_supabase_file(storage_url: str, dest_suffix: str = ".jpg") -> str:
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
            time.sleep(0.3 * (2 ** attempt))
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
