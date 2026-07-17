from fastapi import FastAPI, HTTPException
from app.core.exceptions import http_exception_handler
from app.api.router import api_router

def create_application() -> FastAPI:
    application = FastAPI(
        title="Biometric API Microservice",
        description="Enterprise-grade open-source biometric face processing API powered by ArcFace, RetinaFace, MediaPipe 3D Mesh, and pgvector.",
        version="3.0.0"
    )
    
    application.add_exception_handler(HTTPException, http_exception_handler)
    application.include_router(api_router)
    
    @application.on_event("startup")
    async def warmup_models():
        try:
            from app.core.logging import logger
            from app.services.mediapipe_service import init_mediapipe
            from deepface import DeepFace
            import numpy as np
            
            logger.info("Pre-warming MediaPipe, ArcFace, and PyTorch ML models on startup...")
            init_mediapipe()
            dummy_img = np.zeros((112, 112, 3), dtype=np.uint8)
            _ = DeepFace.represent(img_path=dummy_img, model_name="ArcFace", detector_backend="skip", enforce_detection=False)
            logger.info("ML models successfully warmed up and resident in memory.")
        except Exception as e:
            from app.core.logging import logger
            logger.warning(f"Startup model pre-warming notice: {e}")

    return application

app = create_application()
