from fastapi import APIRouter
from app.api.endpoints import health, enroll, verify, identify, frame

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(enroll.router)
api_router.include_router(verify.router)
api_router.include_router(identify.router)
api_router.include_router(frame.router)
