import os
import time
from collections import defaultdict
from typing import Dict, Any, Optional
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.core.logging import logger

# Security Token Validation
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = credentials.credentials
    expected_token = os.getenv("HF_TOKEN")
    if not expected_token:
        logger.error("HF_TOKEN is not set in environment variables! API access is disabled.")
        raise HTTPException(
            status_code=503,
            detail="API authorization is not configured. Access is disabled."
        )
    if token != expected_token:
        raise HTTPException(
            status_code=401,
            detail="Invalid or missing API authorization token."
        )
    return token

# Rate Limiter
class RateLimiter:
    def __init__(self, requests_limit: int, window_seconds: int):
        self.requests_limit = requests_limit
        self.window_seconds = window_seconds
        self.history = defaultdict(list)

    def is_allowed(self, key: str) -> bool:
        now = time.time()
        self.history[key] = [t for t in self.history[key] if now - t < self.window_seconds]
        if len(self.history[key]) < self.requests_limit:
            self.history[key].append(now)
            return True
        return False

enroll_limiter = RateLimiter(requests_limit=10, window_seconds=60)
identify_limiter = RateLimiter(requests_limit=15, window_seconds=60)
verify_limiter = RateLimiter(requests_limit=15, window_seconds=60)

# In-Memory TTL Cache for Patient Scan Sessions
class SimpleTTLCache:
    def __init__(self, ttl_seconds: int = 300):
        self.ttl = ttl_seconds
        self.cache = {} # Key: user_id/client_ip -> (result_dict, expiry_time)

    def get(self, key: str) -> Optional[Dict[str, Any]]:
        if key in self.cache:
            val, expiry = self.cache[key]
            if time.time() < expiry:
                return val
            else:
                del self.cache[key]
        return None

    def set(self, key: str, value: Dict[str, Any]):
        self.cache[key] = (value, time.time() + self.ttl)

    def clear(self):
        self.cache.clear()

scan_cache = SimpleTTLCache(ttl_seconds=300)
