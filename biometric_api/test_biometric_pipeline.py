import os
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

# Set environment variables for tests before importing main
os.environ["SUPABASE_URL"] = "https://mock-supabase.supabase.co"
os.environ["SUPABASE_SERVICE_ROLE_KEY"] = "mock-key-1234"
os.environ["HF_TOKEN"] = "mock-token-123"

from main import app, evaluate_image_quality

client = TestClient(app)

# Helper to create a dummy image file
def create_dummy_image(path: str, width: int = 500, height: int = 500, color: int = 128, blur: bool = False):
    img = np.ones((height, width, 3), dtype=np.uint8) * color
    if blur:
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
    if os.path.exists("temp_test"):
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
# IMAGE QUALITY VALIDATION TESTS
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
@patch("main.download_supabase_file")
def test_enroll_success(mock_download, mock_supabase, mock_represent, mock_quality, setup_images):
    # Mocking storage image download path
    mock_download.return_value = "temp_test/solid.jpg"

    # Mocking quality assessment (with new pose, occlusion, eyes, and size fields)
    mock_quality.return_value = {
        "success": True,
        "quality_score": 0.95,
        "cropped_face": np.zeros((112, 112, 3)),
        "pose": {"roll": 0.0, "yaw": 0.0, "pitch": 0.0},
        "occlusions": {"wearing_sunglasses": False, "wearing_mask": False},
        "eyes_visible": True,
        "face_percentage_in_frame": 45.0
    }

    # Mocking DeepFace embedding generation
    mock_represent.return_value = [{"embedding": [0.1] * 512, "confidence": 0.98}]

    # Mocking duplicate check (detect_duplicate_biometrics returns empty -> no duplicate)
    mock_supabase.rpc.return_value.execute.return_value.data = []

    # Mocking Supabase patient queries and inserts
    mock_upsert_result = MagicMock()
    mock_upsert_result.data = [{"id": "patient-uuid-123"}]
    mock_supabase.from_.return_value.upsert.return_value.execute.return_value = mock_upsert_result
    mock_supabase.from_.return_value.insert.return_value.execute.return_value = MagicMock()
    mock_supabase.from_.return_value.update.return_value.eq.return_value.execute.return_value = MagicMock()

    response = client.post(
        "/enroll",
        json={
            "userId": "user-uuid-123",
            "selfieUrl": "https://supabase.co/kyc-documents/selfie.jpg",
            "poseLabel": "neutral"
        },
        headers={"Authorization": "Bearer mock-token-123"}
    )
    
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["patient_id"] == "patient-uuid-123"

@patch("main.evaluate_image_quality")
@patch("main.DeepFace.represent")
@patch("main.supabase")
def test_identify_success(mock_supabase, mock_represent, mock_quality):
    # Mocking quality assessment
    mock_quality.return_value = {
        "success": True,
        "quality_score": 0.9,
        "cropped_face": np.zeros((112, 112, 3)),
        "pose": {"roll": 0.0, "yaw": 0.0, "pitch": 0.0},
        "occlusions": {"wearing_sunglasses": False, "wearing_mask": False},
        "eyes_visible": True,
        "face_percentage_in_frame": 45.0
    }

    # Mocking DeepFace embedding generation
    mock_represent.return_value = [{"embedding": [0.1] * 512, "confidence": 0.99}]

    # Mocking RPC and database queries
    def mock_rpc(rpc_name, params=None):
        mock_execute = MagicMock()
        if rpc_name == "detect_duplicate_biometrics":
            mock_execute.execute.return_value.data = []
        elif rpc_name == "match_patient_by_face_consensus":
            mock_execute.execute.return_value.data = [
                {
                    "patient_id": "patient-uuid-123",
                    "qr_code_id": "qr-code-123",
                    "full_name": "John Doe",
                    "pose_label": "smile",
                    "similarity": 0.88,
                    "quality_score": 0.95
                }
            ]
        return mock_execute

    mock_supabase.rpc.side_effect = mock_rpc

    # Mocking the select queries (returns mock enrolled poses for Two-Stage verification)
    mock_select = MagicMock()
    mock_select.data = [
        {"embedding": [0.1] * 512, "pose_label": "smile", "quality_score": 0.95}
    ]
    mock_eq = MagicMock()
    mock_supabase.from_.return_value.select.return_value.eq.return_value = mock_eq
    mock_eq.eq.return_value = mock_eq
    mock_eq.execute.return_value = mock_select

    # Generate a valid dummy encoded JPEG image in bytes
    img = np.ones((500, 500, 3), dtype=np.uint8) * 128
    _, img_encoded = cv2.imencode(".jpg", img)
    jpeg_bytes = img_encoded.tobytes()

    # Send direct multipart file upload in test with authorization headers
    response = client.post(
        "/identify",
        files={"file": ("scan.jpg", jpeg_bytes, "image/jpeg")},
        headers={"Authorization": "Bearer mock-token-123"}
    )

    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["full_name"] == "John Doe"
    assert response.json()["confidence"] > 90.0
    assert response.json()["pose_matched"] == "smile"

@patch("main.evaluate_image_quality")
@patch("main.DeepFace.represent")
@patch("main.supabase")
def test_identify_success_string_embedding(mock_supabase, mock_represent, mock_quality):
    # Mocking quality assessment
    mock_quality.return_value = {
        "success": True,
        "quality_score": 0.9,
        "cropped_face": np.zeros((112, 112, 3)),
        "pose": {"roll": 0.0, "yaw": 0.0, "pitch": 0.0},
        "occlusions": {"wearing_sunglasses": False, "wearing_mask": False},
        "eyes_visible": True,
        "face_percentage_in_frame": 45.0
    }

    # Mocking DeepFace embedding generation
    mock_represent.return_value = [{"embedding": [0.1] * 512, "confidence": 0.99}]

    # Mocking RPC and database queries
    def mock_rpc(rpc_name, params=None):
        mock_execute = MagicMock()
        if rpc_name == "detect_duplicate_biometrics":
            mock_execute.execute.return_value.data = []
        elif rpc_name == "match_patient_by_face_consensus":
            mock_execute.execute.return_value.data = [
                {
                    "patient_id": "patient-uuid-123",
                    "qr_code_id": "qr-code-123",
                    "full_name": "John Doe",
                    "pose_label": "smile",
                    "similarity": 0.88,
                    "quality_score": 0.95
                }
            ]
        return mock_execute

    mock_supabase.rpc.side_effect = mock_rpc

    # Mocking the select queries (returns mock enrolled poses as STRINGS to simulate Supabase prod format)
    mock_select = MagicMock()
    mock_select.data = [
        {"embedding": str([0.1] * 512), "pose_label": "smile", "quality_score": 0.95}
    ]
    mock_eq = MagicMock()
    mock_supabase.from_.return_value.select.return_value.eq.return_value = mock_eq
    mock_eq.eq.return_value = mock_eq
    mock_eq.execute.return_value = mock_select

    # Generate a valid dummy encoded JPEG image in bytes
    img = np.ones((500, 500, 3), dtype=np.uint8) * 128
    _, img_encoded = cv2.imencode(".jpg", img)
    jpeg_bytes = img_encoded.tobytes()

    response = client.post(
        "/identify",
        files={"file": ("scan.jpg", jpeg_bytes, "image/jpeg")},
        headers={"Authorization": "Bearer mock-token-123"}
    )

    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["full_name"] == "John Doe"
    assert response.json()["pose_matched"] == "smile"

@patch("main.evaluate_image_quality")
def test_analyze_frame_success(mock_quality):
    # Mocking quality assessment to return numpy.bool_ for capture_eligible
    mock_quality.return_value = {
        "success": True,
        "quality_score": 0.9,
        "sharpness": 150.0,
        "brightness": 120.0,
        "face_confidence": 0.99,
        "cropped_face": np.zeros((112, 112, 3)),
        "pose": {"roll": 0.0, "yaw": 0.0, "pitch": 0.0},
        "occlusions": {"wearing_sunglasses": False, "wearing_mask": False},
        "eyes_visible": True,
        "face_percentage_in_frame": 45.0,
        "pose_confidence": 90.0,
        "guidance": "Perfect pose",
        "capture_eligible": np.bool_(True),  # Mocking numpy.bool_ specifically
        "_timing_ms": 15.0
    }

    # Generate a valid dummy encoded JPEG image in bytes
    img = np.ones((500, 500, 3), dtype=np.uint8) * 128
    _, img_encoded = cv2.imencode(".jpg", img)
    jpeg_bytes = img_encoded.tobytes()

    response = client.post(
        "/analyze_frame",
        files={"file": ("frame.jpg", jpeg_bytes, "image/jpeg")},
        data={"target_pose": "neutral"}
    )

    assert response.status_code == 200
    res_data = response.json()
    assert res_data["success"] is True
    assert res_data["capture_eligible"] is True  # Should successfully serialize to standard JSON bool

@patch("main.evaluate_image_quality")
def test_analyze_frame_failure_wrong_pose(mock_quality):
    # Mocking quality assessment indicating wrong pose
    mock_quality.return_value = {
        "success": True,
        "quality_score": 0.8,
        "sharpness": 100.0,
        "brightness": 120.0,
        "face_confidence": 0.99,
        "cropped_face": np.zeros((112, 112, 3)),
        "pose": {"roll": 0.0, "yaw": 5.0, "pitch": 0.0},
        "occlusions": {"wearing_sunglasses": False, "wearing_mask": False},
        "eyes_visible": True,
        "face_percentage_in_frame": 45.0,
        "pose_confidence": 60.0,
        "guidance": "Turn your head LEFT more",
        "capture_eligible": False,
        "_timing_ms": 12.0
    }

    img = np.ones((500, 500, 3), dtype=np.uint8) * 128
    _, img_encoded = cv2.imencode(".jpg", img)
    jpeg_bytes = img_encoded.tobytes()

    response = client.post(
        "/analyze_frame",
        files={"file": ("frame.jpg", jpeg_bytes, "image/jpeg")},
        data={"target_pose": "left"}
    )

    assert response.status_code == 200
    res_data = response.json()
    assert res_data["success"] is False
    assert res_data["error_code"] == "WRONG_POSE"
    assert "LEFT more" in res_data["message"]

@patch("main.evaluate_image_quality")
def test_analyze_frame_failure_blurry(mock_quality):
    # Mocking quality assessment indicating blurry image
    mock_quality.return_value = {
        "success": True,
        "quality_score": 0.5,
        "sharpness": 40.0,
        "brightness": 120.0,
        "face_confidence": 0.99,
        "cropped_face": np.zeros((112, 112, 3)),
        "pose": {"roll": 0.0, "yaw": 0.0, "pitch": 0.0},
        "occlusions": {"wearing_sunglasses": False, "wearing_mask": False},
        "eyes_visible": True,
        "face_percentage_in_frame": 45.0,
        "pose_confidence": 75.0,
        "guidance": "Hold still (Image is blurry)",
        "capture_eligible": False,
        "_timing_ms": 10.0
    }

    img = np.ones((500, 500, 3), dtype=np.uint8) * 128
    _, img_encoded = cv2.imencode(".jpg", img)
    jpeg_bytes = img_encoded.tobytes()

    response = client.post(
        "/analyze_frame",
        files={"file": ("frame.jpg", jpeg_bytes, "image/jpeg")},
        data={"target_pose": "neutral"}
    )

    assert response.status_code == 200
    res_data = response.json()
    assert res_data["success"] is False
    assert res_data["error_code"] == "IMAGE_BLUR"
    assert "blurry" in res_data["message"]

