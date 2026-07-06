import os
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

# Set environment variables for tests before importing main
os.environ["SUPABASE_URL"] = "https://mock-supabase.supabase.co"
os.environ["SUPABASE_SERVICE_ROLE_KEY"] = "mock-key-1234"

from main import app, evaluate_image_quality

client = TestClient(app)

# Helper to create a dummy image file
def create_dummy_image(path: str, width: int = 500, height: int = 500, color: int = 128, blur: bool = False):
    img = np.ones((height, width, 3), dtype=np.uint8) * color
    if blur:
        # Generate random noise and blur it to trigger blur detection
        img = cv2.GaussianBlur(img, (21, 21), 0)
    cv2.imwrite(path, img)

@pytest.fixture(scope="module")
def setup_images():
    os.makedirs("temp_test", exist_ok=True)
    
    # 1. Dark image
    create_dummy_image("temp_test/dark.jpg", color=10)
    # 2. Bright image
    create_dummy_image("temp_test/bright.jpg", color=240)
    # 3. Small image
    create_dummy_image("temp_test/small.jpg", width=200, height=200)
    # 4. Blurred image
    create_dummy_image("temp_test/blurred.jpg", blur=True)
    # 5. Normal solid image (will fail face detection but pass other quality checks)
    create_dummy_image("temp_test/solid.jpg", color=128)

    yield

    # Cleanup
    for filename in ["dark.jpg", "bright.jpg", "small.jpg", "blurred.jpg", "solid.jpg"]:
        p = os.path.join("temp_test", filename)
        if os.path.exists(p):
            os.remove(p)
    os.rmdir("temp_test")

# ============================================================================
# HEALTH CHECK TEST
# ============================================================================
def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "online"
    assert response.json()["model"] == "ArcFace (512 dims)"

# ============================================================================
# IMAGE QUALITY VALDIATION TESTS
# ============================================================================
def test_quality_checks_too_dark(setup_images):
    with pytest.raises(Exception) as excinfo:
        evaluate_image_quality("temp_test/dark.jpg")
    assert "Lighting too dark" in str(excinfo.value.detail)

def test_quality_checks_too_bright(setup_images):
    with pytest.raises(Exception) as excinfo:
        evaluate_image_quality("temp_test/bright.jpg")
    assert "Lighting too bright" in str(excinfo.value.detail)

def test_quality_checks_too_small(setup_images):
    with pytest.raises(Exception) as excinfo:
        evaluate_image_quality("temp_test/small.jpg")
    assert "resolution too low" in str(excinfo.value.detail)

def test_quality_checks_blurred(setup_images):
    with pytest.raises(Exception) as excinfo:
        evaluate_image_quality("temp_test/blurred.jpg")
    assert "Image blurred" in str(excinfo.value.detail)

# ============================================================================
# ENROLLMENT & IDENTIFICATION ROUTE TESTS (MOCKED)
# ============================================================================
@patch("main.evaluate_image_quality")
@patch("main.DeepFace.represent")
@patch("main.supabase")
@patch("requests.get")
def test_enroll_success(mock_get, mock_supabase, mock_represent, mock_quality):
    # Mocking storage image download
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.iter_content.return_value = [b"mockimagebytes"]
    mock_get.return_value = mock_response

    # Mocking quality assessment
    mock_quality.return_value = {"success": True, "quality_score": 0.95}

    # Mocking DeepFace embedding generation
    mock_represent.return_value = [{"embedding": [0.1] * 512, "confidence": 0.98}]

    # Mocking Supabase patient queries and inserts
    mock_supabase.from_.return_value.select.return_value.eq.return_value.maybeSingle.return_value.execute.return_value.data = {"id": "patient-uuid-123"}
    mock_supabase.from_.return_value.insert.return_value.execute.return_value = MagicMock()
    mock_supabase.from_.return_value.update.return_value.eq.return_value.execute.return_value = MagicMock()

    response = client.post("/enroll", json={
        "userId": "user-uuid-123",
        "selfieUrl": "https://supabase.co/kyc-documents/selfie.jpg",
        "poseLabel": "neutral"
    })
    
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["patient_id"] == "patient-uuid-123"

@patch("main.evaluate_image_quality")
@patch("main.DeepFace.represent")
@patch("main.supabase")
def test_identify_success(mock_supabase, mock_represent, mock_quality):
    # Mocking quality assessment
    mock_quality.return_value = {"success": True, "quality_score": 0.9}

    # Mocking DeepFace embedding generation
    mock_represent.return_value = [{"embedding": [0.1] * 512, "confidence": 0.99}]

    # Mocking pgvector database matching RPC
    mock_supabase.rpc.return_value.execute.return_value.data = [
        {
            "patient_id": "patient-uuid-123",
            "qr_code_id": "qr-code-123",
            "full_name": "John Doe",
            "pose_label": "smile",
            "similarity": 0.88,
            "quality_score": 0.95
        }
    ]

    # Send direct multipart file upload in test
    response = client.post(
        "/identify",
        files={"file": ("scan.jpg", b"mockscanbytes", "image/jpeg")}
    )

    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["full_name"] == "John Doe"
    assert response.json()["confidence"] == 88.0
    assert response.json()["pose_matched"] == "smile"
