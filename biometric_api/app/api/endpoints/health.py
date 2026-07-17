import sys
import time
from fastapi import APIRouter
from app.core.logging import logger

router = APIRouter()

@router.get("/")
def read_root():
    return {
        "status": "online",
        "pipeline": "production",
        "model": "ArcFace (512 dims)",
        "detector": "MediaPipe",
        "indexing": "pgvector (HNSW)"
    }

@router.get("/diagnostics/mediapipe")
async def diagnostics_mediapipe():
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
