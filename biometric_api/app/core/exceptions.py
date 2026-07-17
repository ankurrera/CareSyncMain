import time
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse

async def http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    error_code = "SERVER_ERROR"
    message = str(detail)
    if isinstance(detail, dict):
        error_code = detail.get("error_code", "SERVER_ERROR")
        message = detail.get("message", str(detail))
    else:
        if exc.status_code == 401:
            error_code = "UNAUTHORIZED"
        elif exc.status_code == 403:
            error_code = "FORBIDDEN"
        elif exc.status_code == 429:
            error_code = "RATE_LIMITED"
        elif exc.status_code == 404:
            error_code = "NO_MATCH_FOUND"
    
    request_id = request.headers.get("X-Request-Id", "unknown")
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "error_code": error_code,
            "message": message,
            "request_id": request_id,
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }
    )
