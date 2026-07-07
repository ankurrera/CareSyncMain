# Testing & Quality Assurance Plan 🧪

This document outlines the testing strategies, automated suites, performance benchmarks, and manual QA checklists for CareSync.

---

## 1. Automated Test Suites

CareSync includes automated unit and integration tests for both the Flutter client and the Python biometric microservice.

### A. Flutter Unit & Widget Tests
Flutter tests are located in the `test/` directory.

#### Test Files
* `ocr_service_test.dart`: Verifies the OCR prescription parser, ensuring scanned text is formatted into structured dosage parameters.
* `extract_medication_test.dart`: Validates dosage calculations and frequency pattern matches.
* `widget_test.dart`: Verifies initial application loading states.

#### Execution Command
```bash
flutter test
```

---

### B. Python Biometric API Tests
Python tests are located in `biometric_api/test_biometric_pipeline.py`.

#### Verified Scenarios
* **Pose Verification**: Ensures yaw, pitch, and roll estimation logic correctly validates angles.
* **Liveness Checks**: Simulates photo attacks and verifies the anti-spoofing rejection filters.
* **Consensus Matching**: Feeds multi-pose records and validates similarity consensus results.
* **Authentication**: Verifies that requests with invalid bearer tokens return `HTTP 401 Unauthorized`.

#### Execution Command
```bash
cd biometric_api
python -m unittest test_biometric_pipeline.py
```

---

## 2. Performance & Benchmark Suite

The biometrics microservice contains a benchmark script (`biometric_api/benchmark_suite.py`) that profiles latency, memory overhead, and recognition accuracy.

### Metrics Collected
* **Face Extraction Latency**: Measures time spent by RetinaFace locating bounding boxes.
* **MediaPipe Landmarks Latency**: Profiles 3D mesh evaluation speed (target is < 30ms).
* **ArcFace Embeddings Latency**: Tracks time taken to generate 512-dimension vectors.
* **Throughput Capacity**: Measures concurrent request performance.

### Running Benchmarks
```bash
cd biometric_api
python benchmark_suite.py
```

---

## 3. Manual Testing Checklists

Developers and QA testers must execute these manual verification steps before submitting PRs:

### A. Face Scan Registration (Guided KYC)
1. Navigate to Profile settings -> Register Biometrics.
2. Verify the camera opens within the app boundaries.
3. Tilt head left: Verify the dynamic HUD overlay registers the left pose.
4. Tilt head right: Verify the HUD registers the right pose.
5. Turn off room lights: Verify the quality engine returns a "LOW_LIGHT" warning and blocks registration.
6. Try enrolling a photo of a person: Verify the liveness check blocks registration with a "LIVENESS_FAILED" error.

### B. Emergency Break Glass Scenario
1. Log in as a Doctor/First Responder.
2. Select Patient Search -> Scan Emergency Face.
3. Point camera at a registered patient's face:
   - Verify the patient is identified with similarity indicators.
   - Verify that an entry is automatically written to `biometric_access_logs`.
   - Verify that the patient profile card displays decrypted vitals.
4. Attempt to edit the access logs in the Supabase table editor: Verify that database policies block editing and delete operations.
