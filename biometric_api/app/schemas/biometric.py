from typing import Optional
from pydantic import BaseModel, Field

class EnrollRequest(BaseModel):
    userId: str = Field(..., description="User ID or Subject Profile ID")
    identityId: Optional[str] = Field(None, alias="patientId", description="Identity ID or Subject ID")
    selfieUrl: Optional[str] = None
    selfieBase64: Optional[str] = None
    poseLabel: str = "neutral"
    enrollment_session_id: Optional[str] = None
    device_info: Optional[str] = None
    camera: Optional[str] = None
    capture_time: Optional[str] = None

class VerifyIDRequest(BaseModel):
    identityId: Optional[str] = Field(None, alias="patientId", description="Target Identity ID for 1:1 verification")
    selfieUrl: Optional[str] = None
    selfieBase64: Optional[str] = None
    idDocumentUrl: Optional[str] = None
    idDocumentBase64: Optional[str] = None

class CompleteEnrollRequest(BaseModel):
    userId: str
    identityId: Optional[str] = Field(None, alias="patientId")
    enrollment_session_id: str

class CleanupEnrollRequest(BaseModel):
    userId: str
    identityId: Optional[str] = Field(None, alias="patientId")
    enrollment_session_id: str
