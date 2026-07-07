# Task list: Doctor Account New Features

- [x] Implement Cryptographic E-Signature secure storage keys & helper methods
- [x] Implement E-Signature settings tile in Doctor's account details card on profile screen
- [x] Create a custom canvas drawing SignatureDialog & SignaturePainter for drawing handwritten signature in profile screen
- [x] Update PdfService to accept and render signature base64 image & SHA-256 hash in signature stamp block
- [x] Modify NewPrescriptionScreen sign-off flow to read signature from secure storage and embed in PDF & metadata
- [x] Watch patient active prescriptions and conditions in NewPrescriptionScreen build
- [x] Write real-time SafetyAlert validator (DDI clashes & Allergy warnings) in NewPrescriptionScreen
- [x] Render safety alerts in a slide-in card underneath medications in NewPrescriptionScreen
- [x] Upgrade PatientRecordScreen to decrypt patient vitals list dynamically
- [x] Draw smooth Bezier curve Line charts for each vital type using CustomPainter (Dual lines for Blood Pressure)
- [x] Clear compilation warnings and resolve analysis check issues
- [x] Add patient profile select link (full_name and gender) to getPatientDataByPatientId in SupabaseService
- [x] Import `supabase_service.dart` in `kyc_verification_screen.dart`
- [x] Modify `_checkExistingKYC()` to query profile/patient tables and prefill fields
- [x] Run standard check/analyze command to ensure code builds correctly
- [x] Verify everything works correctly and document results in `walkthrough.md`
- [x] Upgrade doctorPatientData provider to query by patientId instead of userId
- [x] Upgrade PatientRecordScreen header to show comprehensive demographics grid (Age, Gender, Blood Type, Weight, Height, DOB, Emergency Contact info)
- [x] Upgrade medical conditions list inside PatientRecordScreen to show detail descriptions and severities

## Biometric Face Scan Verification & Accuracy Improvements
- [x] Standardize all FastAPI API error response JSON structures with correlation IDs and timestamps (Phase 1)
- [x] Upgrade CustomBiometricService with strongly typed enums, latency metrics, and safe parsing checks (Phase 2 & 10)
- [x] Map API error codes to human-friendly error descriptions in Flutter (Phase 3)
- [x] Integrate BiometricScanState machine in Doctor scanner screen, Pharmacist dashboard, and Emergency dashboard (Phase 4 & 5)
- [x] Implement camera permission recovery UI with retry and open app settings handlers (Phase 6)
- [x] Implement duplicate scan prevention and configure 4-second matching cooldowns (Phase 7 & 8)
- [x] Implement strict 3-criteria verification consensus (similarity, margin gap >= 0.03, confidence >= 80.0) (Phase 9)
- [x] Conduct comprehensive end-to-end system audit & write final report (Phase 11, 12, & 13)
