import hashlib
import json
import logging
import time
from typing import Dict, Any, Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("production_biometric_api")

def log_telemetry_event(
    endpoint: str,
    request_id: str,
    status: str,
    actor_id: Optional[str] = None,
    latencies_ms: Optional[Dict[str, float]] = None,
    metrics: Optional[Dict[str, Any]] = None
):
    try:
        actor_hash = hashlib.sha256(actor_id.encode("utf-8")).hexdigest() if actor_id else "anonymous"
        payload = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "request_id": request_id,
            "endpoint": endpoint,
            "status": status,
            "actor_id_hash": actor_hash,
            "latencies_ms": latencies_ms or {},
            "metrics": metrics or {}
        }
        logger.info(f"[TELEMETRY] {json.dumps(payload)}")
    except Exception as e:
        logger.warning(f"Telemetry logging notice: {e}")
