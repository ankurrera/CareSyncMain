from typing import Optional
from supabase import create_client, Client
from app.core.config import SUPABASE_URL, SUPABASE_KEY
from app.core.logging import logger

if not SUPABASE_URL or not SUPABASE_KEY:
    logger.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment variables.")
    logger.warning("Please configure .env or pass SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.")

if SUPABASE_URL and SUPABASE_KEY:
    logger.info(f"Connecting to Database / Supabase at: {SUPABASE_URL}")
    supabase: Optional[Client] = create_client(SUPABASE_URL, SUPABASE_KEY)
else:
    supabase = None
