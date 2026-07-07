# API Endpoint Reference 🔌

This document provides technical specifications for the FastAPI Biometrics API endpoints and Supabase Edge functions.

---

## 1. FastAPI Biometrics API

The FastAPI service runs on port `8000` (or inside a Docker/Hugging Face container).

### Authentication Header
All write and search endpoints require a Bearer token:
```http
Authorization: Bearer <HF_TOKEN>
```
If `HF_TOKEN` is not set on the server, requests bypass verification (development mode).

---

### A. POST `/analyze_frame`
* **Purpose**: Analyzes a real-time camera preview frame. Verifies pose and quality metrics.
* **Content-Type**: `multipart/form-data`
* **Request Parameters**:
  - `file` (File, Required): Image bytes (JPEG/PNG).
  - `target_pose` (Form String, Optional): E.g., `neutral`, `left`, `right`.
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "capture_eligible": true,
    "pose": { "yaw": -1.2, "pitch": 5.4, "roll": 0.5 },
    "sharpness": 112.5,
    "brightness": 142.3,
    "face_confidence": 0.98,
    "capture_score": 0.91
  }
  ```
* **Failure Response Example (Low Light)**:
  ```json
  {
    "success": false,
    "capture_eligible": false,
    "error_code": "LOW_LIGHT",
    "message": "Lighting too dark. Please illuminate the face.",
    "instruction": "Position yourself in a brighter area",
    "reason": "Mean brightness level 32.5 below required 45.0 threshold."
  }
  ```

---

### B. POST `/enroll`
* **Purpose**: Generates and registers an embedding vector for a patient pose.
* **Content-Type**: `application/json`
* **Request Payload**:
  ```json
  {
    "userId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "selfieUrl": "kyc-documents/user_id/selfie_neutral.jpg",
    "poseLabel": "neutral",
    "enrollment_session_id": "session-uuid-optional"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "patient_id": "7a123e5a-1111-2222-3333-4a11b22c33d4",
    "embedding_id": "bf88350d-4444-5555-6666-7a88b99c00d1",
    "pose_label": "neutral",
    "quality_score": 0.88,
    "liveness_verified": true
  }
  ```
* **Error Response Example (Duplicate Registration)**:
  ```json
  {
    "success": false,
    "error_code": "ALREADY_ENROLLED",
    "message": "This biometric signature is already enrolled under a different patient profile.",
    "request_id": "a1b2c3d4",
    "timestamp": "2026-07-08T16:15:00Z"
  }
  ```

---

### C. POST `/identify`
* **Purpose**: Searches for a matching patient profile during emergencies using a face photo.
* **Content-Type**: `multipart/form-data`
* **Request Parameters**:
  - `file` (File, Required): Live face photo (JPEG/PNG).
  - `X-Actor-Id` (Header, Required): UUID of the responder requesting the search.
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "patient_id": "7a123e5a-1111-2222-3333-4a11b22c33d4",
    "qr_code_id": "patient-qr-uuid-code",
    "full_name": "John Doe",
    "pose_matched": "neutral",
    "similarity": 0.9452,
    "confidence": 98.4,
    "consensus": {
      "max_similarity": 0.9452,
      "mean_similarity": 0.9201,
      "weighted_similarity": 0.9312
    }
  }
  ```
* **Error Response Example (Ambiguous Face Match)**:
  ```json
  {
    "success": false,
    "error_code": "LOW_CONFIDENCE",
    "message": "Ambiguous match. Multiple profiles appear similarly close. Try scanning again.",
    "request_id": "e5f6g7h8",
    "timestamp": "2026-07-08T16:16:10Z"
  }
  ```

---

### D. POST `/verify_id`
* **Purpose**: Evaluates 1-to-1 match comparing a KYC ID document photo against a user selfie.
* **Content-Type**: `application/json`
* **Request Payload**:
  ```json
  {
    "selfieUrl": "kyc-documents/user_uuid/selfie.jpg",
    "idDocumentUrl": "kyc-documents/user_uuid/passport.jpg"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "verified": true,
    "distance": 0.1245,
    "similarity": 0.8755
  }
  ```

---

## 2. Supabase Edge Functions

### GET `/functions/v1/emergency`
* **Purpose**: Renders a responsive web page showing critical patient details. Scanned by responders.
* **Query Parameters**:
  - `id` (String, Required): The `qr_code_id` UUID of the patient.
* **Headers**:
  - Direct scan via mobile camera bypasses Auth headers (publicly viewable web page containing limited public emergency data).
* **Response Output**: Renders standard HTML + CSS showing the patient's full name, DOB, blood type, public allergies, public medical conditions, and emergency contact list. Registers an access event in `emergency_access_logs` using the client IP.
