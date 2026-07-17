"""
Biometric API Microservice Entrypoint.
Re-exports FastAPI app and core utilities for Uvicorn runtime and test suite compatibility.
"""
# Ensure environment flags and protobuf monkey-patches execute first
import app.core.config

from deepface import DeepFace
from app.core.logging import logger
from app.core.security import (
    verify_token,
    RateLimiter,
    enroll_limiter,
    identify_limiter,
    verify_limiter,
    SimpleTTLCache,
    scan_cache
)
import app.db.supabase as supabase_module
from app.db.supabase import supabase
from app.db.repository import download_supabase_file, log_biometric_access
from app.schemas.biometric import (
    EnrollRequest,
    VerifyIDRequest,
    CompleteEnrollRequest,
    CleanupEnrollRequest
)
from app.services.mediapipe_service import (
    mp_face_mesh,
    init_mediapipe,
    analyze_face_with_mediapipe,
    align_and_crop_with_mediapipe
)
from app.services.quality_service import (
    resize_to_consistent_size,
    estimate_face_pose,
    check_face_occlusions,
    evaluate_image_quality
)
from app.services.deepface_service import (
    has_torch,
    detect_and_align_face
)
from app.services.matching_service import (
    calibrate_match_confidence,
    get_adaptive_max_distance,
    l2_normalize
)

# Import app AFTER defining all main symbols so that endpoints importing `main` find all attributes present.
from app.main import app

__all__ = [
    "app",
    "DeepFace",
    "logger",
    "verify_token",
    "RateLimiter",
    "enroll_limiter",
    "identify_limiter",
    "verify_limiter",
    "SimpleTTLCache",
    "scan_cache",
    "supabase",
    "download_supabase_file",
    "log_biometric_access",
    "EnrollRequest",
    "VerifyIDRequest",
    "CompleteEnrollRequest",
    "CleanupEnrollRequest",
    "mp_face_mesh",
    "init_mediapipe",
    "analyze_face_with_mediapipe",
    "align_and_crop_with_mediapipe",
    "resize_to_consistent_size",
    "estimate_face_pose",
    "check_face_occlusions",
    "evaluate_image_quality",
    "has_torch",
    "detect_and_align_face",
    "calibrate_match_confidence",
    "get_adaptive_max_distance",
    "l2_normalize",
]
