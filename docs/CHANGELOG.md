# Changelog 🗒_

All notable changes to the CareSync project are documented in this file.

---

## [3.0.0] — 2026-07-08

### Added
* **Centroid Match & Multi-Pose Consensus matching**: Upgraded the Python API to run consensus searches against multi-pose vector files (Neutral, Left, Right).
* **Immutability Triggers**: Added the `prevent_audit_changes` trigger to the `biometric_access_logs` and `emergency_access_logs` tables.
* **Auto-Lock lifecycle**: Added the `AppLifecycleService` to auto-lock active user sessions after 15 minutes of inactivity.
* **KYC submissions via RPC**: Implemented the `submit_kyc_verification_secure` database function to handle file path inputs.
* **E-Signature blocks**: Added digital signing fields to the doctor prescription card PDF generator.

### Fixed
* **Infinite RLS Policy Loops**: Implemented the `get_user_role()` database helper function to bypass RLS recursion errors.
* **Biometric access logs FK constraints**: Corrected the foreign key references on `biometric_access_logs` to point to the correct profiles column.
* **RenderFlex alignment**: Corrected input boundaries on the signin forms for smaller devices.

---

## [2.1.0] — 2026-05-15

### Added
* **Medication form auto-calculations**: Integrates drug dosage calculations based on frequency structures.
* **Symmetric encrypted QR**: Implemented AES GCM offline payload encryption for patients' emergency vitals card generation.
* **Chat Room attachments**: Added inline upload configurations for sharing clinical photos between patients and doctors.

---

## [1.0.0] — 2026-01-10
* **Initial Release**: Basic authentication, patient/doctor profile layouts, basic prescription tables, and local biometric guards using `local_auth`.
