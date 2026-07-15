# Testing & Quality Assurance Plan 🧪

This document outlines the testing strategies, automated suites, performance benchmarks, and manual QA checklists for CareSync.

---

## 1. Pre-Flight Validation Command Pipeline

Before committing or pushing any code changes, developers must run the full pre-flight validation sequence to ensure zero warnings or linting regressions:

### Flutter Client
```bash
flutter analyze && dart format --output=none --set-exit-if-changed lib/ && flutter test
```

### Python Biometrics API
Ensure dependencies are clean and all unittest scenarios verify:
```bash
cd biometric_api
python -m unittest test_biometric_pipeline.py
```

---

## 2. Automated Test Suites

### A. Flutter Unit & Widget Tests
Flutter tests are located in the `test/` directory.

#### Test Files
* `ocr_service_test.dart`: Verifies the OCR prescription parser, ensuring scanned text is formatted into structured dosage parameters.
* `extract_medication_test.dart`: Validates dosage calculations and frequency pattern matches.
* `widget_test.dart`: Verifies initial application loading states.
* `production_cert_fixes_test.dart`: Verifies temporary OCR file cleanup and cast null-safety checks.
* `production_hardening_test.dart`: Hardens appointment FSM transitions.

#### Execution Command
```bash
flutter test
```

---

## 3. Performance & Benchmark Suite

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

## 4. Manual Testing Checklists

Developers and QA testers must execute these manual verification steps before submitting updates:

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
