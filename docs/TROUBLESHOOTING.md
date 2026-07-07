# Developer Troubleshooting Handbook 🔍

This guide outlines solutions for common build errors, database issues, model preloading failures, and camera configuration bugs.

---

## 1. Database & Supabase Integration Issues

### Infinite Policy Recursion Loop (Error `42P17`)
* **Problem**: Selecting rows from the `profiles` table triggers a recursive check on policies that reference `profiles`, causing requests to time out.
* **Fix**: Use the database helper function `get_user_role()` instead of querying the table directly within policies. Ensure `supabase/002_schema_fix.sql` has been run:
  ```sql
  SELECT * FROM get_user_role(auth.uid());
  ```

### "Permission Denied" on Table Insertion
* **Problem**: Insert operations are rejected even when authenticated.
* **Fix**: Check that the Row-Level Security (RLS) policies permit insert actions for the user's role. If inserting patient metadata, verify the user has a profile with the `'patient'` role. Run the migration script `021_fix_kyc_rls.sql` to resolve permission issues.

---

## 2. Python Biometrics API & Model Loading

### Weight Download Timeouts
* **Problem**: The server times out during startup while downloading ArcFace weights.
* **Fix**: Run `download_models.py` manually before starting the FastAPI server. If behind a proxy, set system environment proxies or download weights directly from the DeepFace release page and copy them to `~/.deepface/weights/arcface_weights.h5`.

### PyTorch / CUDA Initialization Conflicts
* **Problem**: Liveness checks fail due to Torch CPU/GPU driver conflicts.
* **Fix**:
  - If GPU acceleration is not required, force CPU execution in your environment configuration:
    ```bash
    export CUDA_VISIBLE_DEVICES=""
    ```
  - Ensure the PyTorch installation matches your system's CUDA capabilities.

### Protobuf Version Conflicts
* **Problem**: MediaPipe throws an error during imports: `TypeError: Descriptors cannot not be created directly`.
* **Fix**: CareSync includes a monkey patch at startup to bypass protobuf version constraints. If the error persists, downgrade your protobuf package:
  ```bash
  pip install "protobuf<4.21.0"
  ```

---

## 3. guided Biometric Scan UI & Camera Troubleshooting

### Camera Preview Fails to Open
* **Problem**: Guided face scanning displays a black screen or throws permission errors.
* **Fix**: Verify camera permissions are configured in the native system files:
  - **Android (`android/app/src/main/AndroidManifest.xml`)**:
    ```xml
    <uses-permission android:name="android.permission.CAMERA" />
    ```
  - **iOS (`ios/Runner/Info.plist`)**:
    ```xml
    <key>NSCameraUsageDescription</key>
    <string>CareSync requires camera access to scan biometrics.</string>
    ```

### Camera Guidance Loop Loop (GoRouter circular loops)
* **Problem**: Unlocking the app redirects between the dashboard and biometric scanner continuously.
* **Fix**: Check the role-based shell guards in `lib/routing/app_router.dart`. This redirection loop happens when the database profile role fails to match the active routing shell path, triggering route guard redirections. Double-check your logged-in account's role in the database.
