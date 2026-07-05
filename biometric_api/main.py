import os
import tempfile
import time
import logging
import cv2
import numpy as np
from typing import Dict, Any, List
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
from supabase import create_client, Client
from deepface import DeepFace

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("production_biometric_api")

# Load environment variables from parent or current directories
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
    description="Production-grade biometric face processing microservice with ArcFace, RetinaFace, OpenCV and pgvector.",
    version="2.0.0"
)

# Pydantic models for request validation
class EnrollRequest(BaseModel):
    userId: str
    selfieUrl: str
    poseLabel: str = "neutral"

class IdentifyRequest(BaseModel):
    scanPath: str

class VerifyIDRequest(BaseModel):
    selfieUrl: str
    idDocumentUrl: str

# ============================================================================
# IMAGE PROCESSING & QUALITY EVALUATION ENGINE
# ============================================================================

def evaluate_image_quality(img_path: str) -> Dict[str, Any]:
    """
    Evaluates image quality using OpenCV metrics before face embedding.
    Checks: Resolution, Brightness, Blur/Sharpness, Contrast, and Occlusion/Faces.
    """
    img = cv2.imread(img_path)
    if img is None:
        raise HTTPException(status_code=400, detail="Cannot read image. File may be corrupted.")

    h, w, c = img.shape
    
    # 1. Resolution Check
    if h < 480 or w < 480:
        raise HTTPException(
            status_code=400, 
            detail=f"Image resolution too low ({w}x{h}). Minimum required is 480x480 pixels."
        )

    # Convert to grayscale for calculations
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 2. Exposure / Brightness Check (Average Pixel Intensity)
    mean_brightness = np.mean(gray)
    logger.info(f"Image average brightness: {mean_brightness:.2f}")
    if mean_brightness < 40:
        raise HTTPException(status_code=400, detail="Lighting too dark. Please illuminate the face.")
    if mean_brightness > 225:
        raise HTTPException(status_code=400, detail="Lighting too bright / overexposed. Please adjust lighting.")

    # 3. Blur / Sharpness Check (Laplacian Variance Method)
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    logger.info(f"Image sharpness score (Laplacian Variance): {laplacian_var:.2f}")
    # Threshold < 65 indicates high blur
    if laplacian_var < 65.0:
        raise HTTPException(status_code=400, detail="Image blurred or out of focus. Please hold the camera still.")

    # 4. Contrast Check (Standard Deviation of pixel values)
    contrast_score = np.std(gray)
    logger.info(f"Image contrast score: {contrast_score:.2f}")
    if contrast_score < 20:
        raise HTTPException(status_code=400, detail="Image contrast too low. Background and subject must contrast.")

    # 5. Face Detection, Alignment, and Quantity checks
    try:
        # MediaPipe is a highly optimized, lightweight CPU-friendly detector
        faces = DeepFace.extract_faces(
            img_path=img_path, 
            detector_backend="mediapipe", 
            enforce_detection=True
        )
    except ValueError as ve:
        logger.warning(f"No face detected in image: {ve}")
        raise HTTPException(
            status_code=400, 
            detail="No face detected. Please position the camera directly in front of the face."
        )

    if len(faces) == 0:
        raise HTTPException(status_code=400, detail="No face detected in image.")
    
    # Reject multiple faces to ensure secure identification
    if len(faces) > 1:
        raise HTTPException(status_code=400, detail="Multiple faces detected. Please capture only one person.")

    face = faces[0]
    face_conf = face.get("confidence", 0.0)
    logger.info(f"Face detection confidence: {face_conf:.4f}")
    if face_conf < 0.85:
        raise HTTPException(status_code=400, detail="Face detection confidence too low. Verify lighting and angle.")

    facial_area = face["facial_area"]
    wf, hf = facial_area["w"], facial_area["h"]
    logger.info(f"Face bounding box: {wf}x{hf}")
    
    # Rejects tiny faces (e.g. face captured from too far)
    if wf < 120 or hf < 120:
        raise HTTPException(status_code=400, detail="Face too small or too far. Please move closer to the camera.")

    # Quality score is mapped based on sharpness and brightness deviations
    quality_score = min(1.0, (laplacian_var / 120.0)) * (1.0 - abs(128.0 - mean_brightness) / 128.0)

    return {
        "success": True,
        "quality_score": float(quality_score),
        "sharpness": float(laplacian_var),
        "brightness": float(mean_brightness),
        "face_confidence": float(face_conf)
    }

def enhance_image(img_path: str) -> str:
    """
    Applies histogram equalization (CLAHE) and bilateral filtering to enhance facial details
    and reduce noise under low-light or uneven-light situations.
    """
    img = cv2.imread(img_path)
    if img is None:
        return img_path

    # Convert to LAB space to equalize brightness channel L
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    
    # Contrast Limited Adaptive Histogram Equalization
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    cl = clahe.apply(l)
    
    limg = cv2.merge((cl, a, b))
    enhanced = cv2.cvtColor(limg, cv2.COLOR_LAB2BGR)
    
    # Bilateral filter (smooths surfaces while keeping edges sharp)
    enhanced = cv2.bilateralFilter(enhanced, 5, 45, 45)
    
    # Write enhanced image to a temporary file
    temp_enhanced = tempfile.NamedTemporaryFile(delete=False, suffix=".jpg")
    cv2.imwrite(temp_enhanced.name, enhanced)
    return temp_enhanced.name

# ============================================================================
# ENDPOINTS
# ============================================================================

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
async def enroll(payload: EnrollRequest):
    """
    Enrolls a patient's face by downloading their selfie,
    evaluating image quality, extracting the ArcFace embedding vector,
    and storing it in the 'patient_embeddings' table.
    """
    start_time = time.time()
    temp_img_path = None
    enhanced_path = None
    try:
        logger.info(f"Enrolling pose '{payload.poseLabel}' for user: {payload.userId}")
        
        # 1. Fetch image from Supabase Storage
        import requests
        response = requests.get(payload.selfieUrl, stream=True)
        if response.status_code != 200:
            raise HTTPException(
                status_code=400, 
                detail="Failed to retrieve selfie from storage server."
            )
            
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
            for chunk in response.iter_content(chunk_size=8192):
                temp_file.write(chunk)
            temp_img_path = temp_file.name

        # 2. Quality Evaluation
        quality_metrics = evaluate_image_quality(temp_img_path)
        logger.info(f"Quality validation passed: {quality_metrics}")

        # 3. Automatic Contrast/Light Enhancement
        enhanced_path = enhance_image(temp_img_path)

        # 4. Generate ArcFace embedding
        embeddings = DeepFace.represent(
            img_path=enhanced_path,
            model_name="ArcFace",
            detector_backend="mediapipe",
            enforce_detection=True
        )

        if not embeddings or len(embeddings) == 0:
            raise HTTPException(
                status_code=400,
                detail="Failed to generate biometric signature from the photo."
            )

        embedding_vector = embeddings[0]["embedding"]

        # 5. Fetch patient record ID from the patients table using user_id
        patient_query = supabase.from_("patients").select("id").eq("user_id", payload.userId).maybeSingle().execute()
        
        if not patient_query.data:
            # Patient row doesn't exist yet, insert a basic row to generate the primary key ID
            logger.info("No patient row found. Generating new entry in 'patients' table...")
            insert_query = supabase.from_("patients").insert({"user_id": payload.userId}).execute()
            if not insert_query.data:
                raise HTTPException(status_code=500, detail="Failed to initialize patient record in database.")
            patient_id = insert_query.data[0]["id"]
        else:
            patient_id = patient_query.data["id"]

        # 6. Store vector in 'patient_embeddings'
        logger.info(f"Saving pose vector to patient_embeddings table for patient ID: {patient_id}")
        supabase.from_("patient_embeddings").insert({
            "patient_id": patient_id,
            "embedding": embedding_vector,
            "pose_label": payload.poseLabel,
            "quality_score": quality_metrics["quality_score"]
        }).execute()

        # Update patient table's general face scan url
        supabase.from_("patients").update({
            "face_scan_url": payload.selfieUrl,
            "updated_at": "now()"
        }).eq("id", patient_id).execute()

        logger.info(f"Enrollment completed in {time.time() - start_time:.4f} seconds.")
        return {
            "success": True,
            "patient_id": patient_id,
            "quality_metrics": quality_metrics,
            "pose_enrolled": payload.poseLabel,
            "latency_seconds": time.time() - start_time
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Biometric enrollment failed")
        raise HTTPException(status_code=500, detail=f"Enrollment failed: {str(e)}")
    finally:
        # File Cleanup
        if temp_img_path and os.path.exists(temp_img_path):
            os.remove(temp_img_path)
        if enhanced_path and os.path.exists(enhanced_path):
            os.remove(enhanced_path)

@app.post("/verify_id")
async def verify_id(payload: VerifyIDRequest):
    """
    Compares the face in a live selfie against the face on an ID document
    using DeepFace.verify with ArcFace and MediaPipe.
    """
    temp_selfie_path = None
    temp_id_path = None
    try:
        logger.info("Comparing face from selfie against ID document.")
        import requests
        
        # Download selfie
        selfie_res = requests.get(payload.selfieUrl, stream=True)
        if selfie_res.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to retrieve selfie.")
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f:
            for chunk in selfie_res.iter_content(chunk_size=8192):
                f.write(chunk)
            temp_selfie_path = f.name

        # Download ID Document
        id_res = requests.get(payload.idDocumentUrl, stream=True)
        if id_res.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to retrieve ID document.")
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f:
            for chunk in id_res.iter_content(chunk_size=8192):
                f.write(chunk)
            temp_id_path = f.name

        # Perform verification
        result = DeepFace.verify(
            img1_path=temp_selfie_path,
            img2_path=temp_id_path,
            model_name="ArcFace",
            detector_backend="mediapipe",
            enforce_detection=True
        )
        
        similarity = 1.0 - float(result["distance"])
        verified = bool(result["verified"])
        logger.info(f"Comparison result: verified={verified}, distance={result['distance']:.4f}")
        
        return {
            "success": True,
            "verified": verified,
            "distance": float(result["distance"]),
            "similarity": float(similarity)
        }
    except Exception as e:
        logger.exception("Face comparison failed")
        raise HTTPException(status_code=500, detail=f"Comparison failed: {str(e)}")
    finally:
        if temp_selfie_path and os.path.exists(temp_selfie_path):
            os.remove(temp_selfie_path)
        if temp_id_path and os.path.exists(temp_id_path):
            os.remove(temp_id_path)

@app.post("/identify")
async def identify(payload: IdentifyRequest):
    """
    Identifies a patient by downloading a scanned face from the temporary
    'emergency-scans' bucket, executing quality checks, extracting its embedding,
    and searching the pgvector database using the match_patient_by_face_multi RPC.
    """
    start_time = time.time()
    temp_img_path = None
    enhanced_path = None
    try:
        logger.info(f"Received identification scan request: {payload.scanPath}")
        
        # 1. Download image bytes from Supabase private storage
        download_start = time.time()
        try:
            file_bytes = supabase.storage.from_("emergency-scans").download(payload.scanPath)
        except Exception as se:
            logger.error(f"Failed to retrieve scan file from Supabase storage: {se}")
            raise HTTPException(
                status_code=400, 
                detail="Scanned file could not be downloaded from backend storage."
            )
        download_latency = time.time() - download_start

        # 2. Save bytes locally
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
            temp_file.write(file_bytes)
            temp_img_path = temp_file.name

        # 3. Quality Evaluation
        quality_start = time.time()
        quality_metrics = evaluate_image_quality(temp_img_path)
        logger.info(f"Quality evaluation passed: {quality_metrics}")
        quality_latency = time.time() - quality_start

        # 4. Image Contrast / Light Enhancement
        enhancement_start = time.time()
        enhanced_path = enhance_image(temp_img_path)
        enhancement_latency = time.time() - enhancement_start

        # 5. Extract ArcFace embedding
        inference_start = time.time()
        embeddings = DeepFace.represent(
            img_path=enhanced_path,
            model_name="ArcFace",
            detector_backend="mediapipe",
            enforce_detection=True
        )

        if not embeddings or len(embeddings) == 0:
            raise HTTPException(
                status_code=400,
                detail="Failed to generate face signature from scan."
            )

        embedding_vector = embeddings[0]["embedding"]
        inference_latency = time.time() - inference_start

        # 6. Database pgvector Match
        db_start = time.time()
        # Cosine distance limit of 0.35 equates to >= 65% similarity
        rpc_res = supabase.rpc("match_patient_by_face_multi", {
            "query_embedding": embedding_vector,
            "max_distance": 0.35,
            "match_limit": 10
        }).execute()
        db_latency = time.time() - db_start

        match_data = rpc_res.data
        if not match_data or len(match_data) == 0:
            logger.info("No matching face vector found in registry database.")
            raise HTTPException(
                status_code=404,
                detail="No matching patient profile found in database."
            )

        # 7. False Positive Reduction (Compare best match against secondary candidate)
        best_match = match_data[0]
        confidence = best_match["similarity"] * 100
        
        # Second-pass verification: Check margin if multiple candidates are returned
        margin = 0.0
        if len(match_data) > 1:
            second_match = match_data[1]
            margin = best_match["similarity"] - second_match["similarity"]
            # If the best match is extremely close to the second match (less than 3% margin),
            # and the overall similarity is low, we trigger duplicate suppression to avoid false matching.
            if margin < 0.03 and best_match["similarity"] < 0.72:
                logger.warning(f"Ambiguous match margin: {margin:.4f}. Candidates: {best_match['full_name']} vs {second_match['full_name']}")
                raise HTTPException(
                    status_code=404,
                    detail="Ambiguous face match detected. Please ensure only the patient is in frame and retry."
                )

        total_latency = time.time() - start_time
        logger.info(f"Successful match: {best_match['full_name']} | Confidence: {confidence:.2f}% | Latency: {total_latency:.4f}s")

        return {
            "success": True,
            "patient_id": best_match["patient_id"],
            "qr_code_id": best_match["qr_code_id"],
            "full_name": best_match["full_name"],
            "pose_matched": best_match["pose_label"],
            "similarity": best_match["similarity"],
            "confidence": confidence,
            "match_margin": margin,
            "quality_metrics": quality_metrics,
            "benchmarks": {
                "download_time": download_latency,
                "quality_time": quality_latency,
                "enhancement_time": enhancement_latency,
                "inference_time": inference_latency,
                "database_search_time": db_latency,
                "total_time": total_latency
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Identification process failed")
        raise HTTPException(status_code=500, detail=f"Biometric matching failed: {str(e)}")
    finally:
        # File Cleanup
        if temp_img_path and os.path.exists(temp_img_path):
            os.remove(temp_img_path)
        if enhanced_path and os.path.exists(enhanced_path):
            os.remove(enhanced_path)
