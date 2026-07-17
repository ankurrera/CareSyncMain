import time
import json
import math
import cv2
import numpy as np
from collections import defaultdict
from fastapi import APIRouter, Request, UploadFile, File, Depends, Header, BackgroundTasks, HTTPException

import main
from app.core.security import verify_token

router = APIRouter()

@router.post("/identify")
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
    if not main.identify_limiter.is_allowed(client_ip):
        background_tasks.add_task(
            main.log_biometric_access,
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

    try:
        file_bytes = await file.read()
        if not file_bytes:
            raise HTTPException(
                status_code=400,
                detail={
                    "error_code": "EMPTY_IMAGE",
                    "message": "Uploaded file is empty."
                }
            )

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

        quality_metrics = main.evaluate_image_quality(img, run_liveness=True)
        occlusions = quality_metrics["occlusions"]
        quality_score = quality_metrics["quality_score"]

        main.logger.info(f"[IDENTIFY DIAGNOSTIC] raw quality_score={quality_score:.4f}")

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
                    "message": "Failed to build signature from scan."
                }
            )
        query_vector = main.l2_normalize(embeddings[0]["embedding"])

        pose = quality_metrics.get("pose", {"yaw": 0.0, "pitch": 0.0, "roll": 0.0})
        yaw = abs(pose.get("yaw", 0.0))
        pitch = abs(pose.get("pitch", 0.0))
        is_profile_scan = yaw > 15.0 or pitch > 12.0

        adaptive_max_distance = main.get_adaptive_max_distance(quality_score)
        rpc_res = main.supabase.rpc("match_patient_by_face_consensus", {
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

        # Candidate pose retrieval (single candidate .eq for test mock compatibility, .in_ for multi-candidate batching)
        candidate_ids = [cand["patient_id"] for cand in match_candidates]
        candidate_map = {cand["patient_id"]: cand for cand in match_candidates}
        poses_by_patient = defaultdict(list)
        
        if len(candidate_ids) == 1:
            pid = candidate_ids[0]
            poses_res = main.supabase.from_("patient_embeddings")\
                .select("patient_id, embedding, pose_label, quality_score, yaw, pitch, roll")\
                .eq("patient_id", pid)\
                .eq("is_active", True)\
                .execute()
            if poses_res.data and isinstance(poses_res.data, list):
                for p_rec in poses_res.data:
                    p_rec["patient_id"] = pid
                    poses_by_patient[pid].append(p_rec)
        else:
            all_poses_res = main.supabase.from_("patient_embeddings")\
                .select("patient_id, embedding, pose_label, quality_score, yaw, pitch, roll")\
                .in_("patient_id", candidate_ids)\
                .eq("is_active", True)\
                .execute()
            if all_poses_res.data and isinstance(all_poses_res.data, list):
                for p_rec in all_poses_res.data:
                    poses_by_patient[p_rec.get("patient_id")].append(p_rec)

        query_yaw = pose.get("yaw", 0.0)
        query_pitch = pose.get("pitch", 0.0)

        raw_matches = []
        for pid, cand in candidate_map.items():
            enrolled_poses = poses_by_patient.get(pid, [])
            if not enrolled_poses:
                continue

            pose_similarities = []
            weights = []
            for p_rec in enrolled_poses:
                v_raw = p_rec["embedding"]
                if isinstance(v_raw, str):
                    try:
                        v_raw = json.loads(v_raw)
                    except Exception:
                        v_raw = [float(x) for x in v_raw.strip('[]').split(',')]
                v_enrolled = np.array(v_raw)
                sim = np.dot(query_vector, v_enrolled)
                pose_similarities.append(sim)

                # Pose-aware angular distance weighting
                rec_yaw = p_rec.get("yaw") if p_rec.get("yaw") is not None else 0.0
                rec_pitch = p_rec.get("pitch") if p_rec.get("pitch") is not None else 0.0
                angle_dist = math.sqrt((query_yaw - rec_yaw)**2 + (query_pitch - rec_pitch)**2)
                angle_weight = math.exp(-(angle_dist ** 2) / (2 * (35.0 ** 2)))
                quality_w = p_rec.get("quality_score") or 1.0
                
                weights.append(quality_w * angle_weight)
            
            if not pose_similarities:
                continue
                
            max_sim = max(pose_similarities)
            mean_sim = sum(pose_similarities) / len(pose_similarities)
            weighted_sim = sum(s * w for s, w in zip(pose_similarities, weights)) / sum(weights)

            raw_matches.append({
                "identity_id": cand.get("identity_id") or cand.get("patient_id"),
                "patient_id": cand.get("patient_id") or cand.get("identity_id"),
                "external_id": cand.get("external_id") or cand.get("qr_code_id"),
                "qr_code_id": cand.get("qr_code_id") or cand.get("external_id"),
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

        raw_matches.sort(key=lambda x: x["similarity"], reverse=True)
        best_match = raw_matches[0]

        min_similarity_gate = 1.0 - adaptive_max_distance
        if best_match["similarity"] < min_similarity_gate:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "NO_MATCH_FOUND",
                    "message": "Biometric verification failed (below threshold)."
                }
            )

        if best_match["consensus"]["mean_similarity"] < 0.34:
            raise HTTPException(
                status_code=404,
                detail={
                    "error_code": "NO_MATCH_FOUND",
                    "message": "Biometric verification failed (consensus threshold not met)."
                }
            )

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

        confidence = main.calibrate_match_confidence(best_match["similarity"])
        main.logger.info(
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

        background_tasks.add_task(
            main.log_biometric_access,
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
        main.logger.warning(f"[IDENTIFY FAILED] actor={x_actor_id} request_id={request_id} "
                       f"error_code={err_code} message={err_msg}")
        background_tasks.add_task(
            main.log_biometric_access,
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
        main.logger.error(f"[IDENTIFY FAILED] actor={x_actor_id} request_id={request_id} "
                     f"error_code=SERVER_ERROR message={str(e)}")
        background_tasks.add_task(
            main.log_biometric_access,
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
