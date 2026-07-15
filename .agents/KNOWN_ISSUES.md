# KNOWN ISSUES — my-new-app

This file is a living log of discovered bugs, resolved issues, and deferred items.
Agents MUST read this before debugging any reported issue.

**Legend:**
- 🟢 Resolved — Fixed and merged.
- 🟡 Deferred — Known, not yet fixed.
- 🔴 Active — Currently broken.
- ⚪ Wont Fix — Intentional or too low impact.

---

## Issues

### 🟢 KI-001: Biometric API Latency (MediaPipe Alignment)
- **Symptom**: Selfie recognition and registration requests taking ~20.0 seconds to execute on Cloud Run.
- **Root Cause**: DeepFace's internal BlazeFace detector failed on rotated/tilted faces, causing a CPU fallback to RetinaFace (taking ~19.9s).
- **Fix**: Implemented custom 3-point similarity transform alignment using pre-computed MediaPipe FaceMesh landmarks in Python (~2ms) and relaxed HNSW matching bounds.
- **Files**: [main.py](file:///Users/zen/Documents/GitHub/CareSyncMain/biometric_api/main.py)
- **Resolved**: 2026-07-14

### 🟢 KI-002: Biometric Access Logs FK Constraint Violation
- **Symptom**: Enrollment failing with foreign key violation errors on `biometric_access_logs`.
- **Root Cause**: The API mapped the authentication UUID to `target_patient_id` directly instead of querying the internal UUID from the `patients` table.
- **Fix**: Pre-fetched the patient ID associated with the user ID prior to logging.
- **Files**: [main.py](file:///Users/zen/Documents/GitHub/CareSyncMain/biometric_api/main.py)
- **Resolved**: 2026-07-14

### 🟢 KI-003: PyTorch NNPACK Hardware Warning Logs
- **Symptom**: Stdout log pollution with PyTorch hardware compatibility warnings.
- **Root Cause**: CPU NNPACK checks running on container start.
- **Fix**: Configured `os.environ["TORCH_CPP_MIN_LOG_LEVEL"] = "3"` and python warning silencers at startup.
- **Files**: [main.py](file:///Users/zen/Documents/GitHub/CareSyncMain/biometric_api/main.py)
- **Resolved**: 2026-07-14

### 🟢 KI-004: Pharmacist Dispense Verification Security Mismatch
- **Symptom**: Pharmacist face scan matches correctly in backend but shows a "Security Mismatch" error dialog in the app.
- **Root Cause**: The client-side code compared the identified `patients.id` UUID with the patient's `user_id` UUID, which are distinct.
- **Fix**: Updated the comparison to match `identifyResult.patientId` against the expected `patients.id` (`_patient['id']`).
- **Files**: [dispense_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/dispense_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-005: Pharmacist Profile Screen & Logout Inaccessible
- **Symptom**: Pharmacists could not access their profile screen or log out of their account from the dashboard.
- **Root Cause**: The pharmacist dashboard hero header (containing the avatar and user greeting text) was not interactive and lacked any navigation triggers.
- **Fix**: Wrapped the profile row in a `GestureDetector` that routes to `RouteNames.profile` on tap, and added a visual chevron/arrow icon for UI feedback.
- **Files**: [pharmacist_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/pharmacist_dashboard_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-006: Sign In/Up Input Field Focused Border Line
- **Symptom**: Colored border highlights were displaying around input fields when selected (focused) on authentication screens.
- **Root Cause**: The input decorations explicitly styled `focusedBorder` and `focusedErrorBorder` with active colors (`t.accent` and wider borders).
- **Fix**: Updated `focusedBorder` and `focusedErrorBorder` to match the passive `enabledBorder`/`errorBorder` styling (width 1, divider/error colors) to remove the focus highlight lines.
- **Files**: [sign_in_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/auth/presentation/screens/sign_in_screen.dart), [sign_up_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/auth/presentation/screens/sign_up_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-007: Liveness Check Spoofing False Positives (LIVENESS_FAILED)
- **Symptom**: Real faces matching correctly in enrollment/recognition are flagged as spoof attempts (`LIVENESS_FAILED`) on neutral views.
- **Root Cause**: The liveness check was run directly on the tightly cropped `112x112` face. The anti-spoofing model (MiniFASNet) requires surrounding head and background context to detect real 3D faces vs 2D screens, so it threw false positives.
- **Fix**: Modified the MediaPipe path to dynamically calculate a bounding box with **60% padding** around the face. The liveness check is now run on this padded crop context, preserving critical background signatures.
- **Files**: [main.py](file:///Users/zen/Documents/GitHub/CareSyncMain/biometric_api/main.py)
- **Resolved**: 2026-07-14

### 🟢 KI-008: Inconsistent Dashboard Card Border Widths & Empty States
- **Symptom**: The "Upcoming Appointments" and "Today's Medications" empty state cards had thick 1.5px borders, whereas all other dashboard cards had clean 1.0px borders. The empty cards also lacked informative subtext and width constraints.
- **Fix**: Changed empty state border widths to match the app standard (1.0px / default divider border). Aligned them to full width using `SizedBox(width: double.infinity)` and added clean, supportive secondary subtexts describing what will appear in those sections.
- **Files**: [appointment_list_widget.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/widgets/appointment_list_widget.dart), [daily_medication_schedule.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/presentation/widgets/daily_medication_schedule.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-009: Pharmacist Dashboard Empty State UI Alignment
- **Symptom**: The "Pending Prescriptions" empty state card on the pharmacist dashboard had inconsistent layout styling, large icon circles, custom height constraints, and wide margins, breaking dashboard unity.
- **Fix**: Replaced the placeholder with the unified dashboard empty-state design (28px gray icons, 1.0px borders, explicit `double.infinity` width alignment, and clean subtexts).
- **Files**: [pharmacist_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/pharmacist_dashboard_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-010: Pharmacist Header & Search Bar Focus Highlight
- **Symptom**: The profile navigation chevron on the pharmacist header was plain, and the search input field highlighted with a thick active colored outline on selection (focus), breaking the clean styling guidelines.
- **Fix**: Upgraded the header chevron to a premium circular accent button with `Iconsax.arrow_right_3`. Redesigned the search input field on the search screen with a softer `16px` border radius and configured `focusedBorder` to match the passive `enabledBorder` (t.divider). On the dashboard, replaced the read-only `TextField` mock with a static, clean `Row` container to prevent any keyboard or focus outlines from appearing on selection.
- **Files**: [pharmacist_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/pharmacist_dashboard_screen.dart), [pharmacist_search_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/pharmacist_search_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-011: Sign Out Redirection Lock (Cached Provider State)
- **Symptom**: When a user (e.g. Pharmacist) clicked the "Sign Out" button inside their profile screen, they would remain stuck in a half-logged-out state on the profile view.
- **Root Cause**: The router evaluated `isAuthenticated` using Riverpod's `authStateProvider.valueOrNull != null`. During the sign-out loading transition, Riverpod preserved the cached authenticated user state inside `valueOrNull`, causing the router to evaluate auth as `true` and skip the sign-out redirect.
- **Fix**: Replaced the Riverpod async check inside the GoRouter `redirect` logic with a direct, synchronous check on the Supabase singleton state: `SupabaseService.instance.isAuthenticated`. This guarantees instant, reliable routing to the role selection screen on logout.
- **Files**: [app_router.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/routing/app_router.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-012: Child Role Tables RLS Insert / Upsert Block
- **Symptom**: User registration or pharmacist/doctor profile details edit throws a database error: `new row violates row-level security policy for table "pharmacists"` (or `"doctors"` / `"profiles"`).
- **Root Cause**: 
  1. The mobile app calls `upsert` queries on secondary role tables (like `pharmacists` and `doctors`) without specifying an `onConflict` resolution key. Because the primary key of these tables is a generated UUID (`id`) rather than the unique `user_id` foreign key, PostgREST attempts to perform an `INSERT` of a duplicate record instead of updating the existing one.
  2. In addition, the `profiles` table lacked a `FOR INSERT` policy under RLS, which blocked upsert plans because an `upsert` query translates to `INSERT ... ON CONFLICT DO UPDATE` and requires `INSERT` privileges.
- **Fix**: Added `onConflict: 'user_id'` to the `doctors` and `pharmacists` upsert calls inside `upsertProfile` and the authentication provider. Added database migrations [`047_fix_profiles_insert_rls.sql`](file:///Users/zen/Documents/GitHub/CareSyncMain/supabase/047_fix_profiles_insert_rls.sql) and [`049_fix_pharmacists_rls_individual.sql`](file:///Users/zen/Documents/GitHub/CareSyncMain/supabase/049_fix_pharmacists_rls_individual.sql) to set explicit individual SELECT, INSERT, UPDATE, and DELETE RLS policies.
- **Files**: [047_fix_profiles_insert_rls.sql](file:///Users/zen/Documents/GitHub/CareSyncMain/supabase/047_fix_profiles_insert_rls.sql), [049_fix_pharmacists_rls_individual.sql](file:///Users/zen/Documents/GitHub/CareSyncMain/supabase/049_fix_pharmacists_rls_individual.sql), [supabase_service.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/services/supabase_service.dart), [auth_provider.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/auth/providers/auth_provider.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-013: Hardcoded Doctor Lists on Patient Dashboard
- **Symptom**: The patient dashboard displayed a static, hardcoded list of mockup doctors (Dr. Priya Sharma & Dr. Rohan Verma), instead of the actual medical professionals the patient has or had appointments with.
- **Root Cause**: The dashboard layout was hardcoded to display static mockup widgets instead of querying the backend database. In addition, the upcoming appointments list loader didn't fetch nested doctor metadata from the `doctors` table when performing joins.
- **Fix**: Updated the `getUpcomingAppointments` query to select nested `doctors(*)` data and flatten the properties into the returned model. Implemented a new `getPatientAppointmentsHistory` query and generated `patientDoctorsProvider` to select unique doctor profiles matching the patient's appointment records. Replaced the static widgets on the dashboard with a dynamic ListView that loads consultations history, complete with a clean empty state card.
- **Files**: [patient_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/presentation/screens/patient_dashboard_screen.dart), [appointment_provider.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/providers/appointment_provider.dart), [appointment_service.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/services/appointment_service.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-014: Grey Background Overlays Under Action Text on Patient Dashboard
- **Symptom**: Low-opacity grey pill-shaped background highlights appeared behind header buttons (like "View All", "See History", "Book New") on the patient dashboard.
- **Root Cause**: The layout used default `TextButton` widgets which, depending on Material 3 platform defaults, inherit active state splash overlays or focus pill backgrounds.
- **Fix**: Replaced the `TextButton` widget inside `_sectionHeader` with a clean `GestureDetector` wrapped in target-sized padding. This guarantees no visual overlays, shadows, or background elements are ever rendered.
- **Files**: [patient_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/presentation/screens/patient_dashboard_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-015: Premature Screen Title Truncation in LinearFadeAppBar
- **Symptom**: Page header heading text was truncated early (e.g. "Emerge..") instead of rendering the complete title.
- **Fix**: Replaced the `Spacer` and `Flexible` row structure inside `LinearFadeAppBar` with `Expanded` so the text occupies all remaining space between the leading and trailing slots. In addition, centralized all hardcoded screen titles into a centralized resource class [`screen_titles.dart`](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/routing/screen_titles.dart) for clean and easy title management.
- **Files**: [linear_fade_appbar.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/core/design/linear_fade_appbar.dart), [screen_titles.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/routing/screen_titles.dart), and affected screen files.
- **Resolved**: 2026-07-14

### 🟢 KI-016: BoxShadow Glow Styling in Layout Components
- **Symptom**: Colored decorative shadow glow elements appeared behind floating bottom nav bars, circular Floating Action Buttons (FABs), progress step indicators, and list status chips.
- **Root Cause**: Components used decorative `BoxShadow` offsets with solid accent colors at high opacities to produce glow halos.
- **Fix**: Searched the entire codebase for all instances of `BoxShadow` properties and removed them, enforcing a completely flat, clean modern design language across all screens.
- **Files**: [circular_icon_button.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/core/design/circular_icon_button.dart), [cs_floating_nav_bar.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/presentation/widgets/cs_floating_nav_bar.dart), [premium_face_scan_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/auth/presentation/screens/premium_face_scan_screen.dart), [doctor_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/doctor/presentation/screens/doctor_dashboard_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-017: Discrepant Facial Recognition Scan HUD UI across Provider Apps
- **Symptom**: The doctor app, pharmacist app, and emergency centre rendered different full-screen loader overlays and scanning visual vectors during facial recognition.
- **Root Cause**: There was no shared biometric scanning overlay component; screens duplicated different layouts (e.g. circle indicators, custom paint vectors, or simple circular progress indicators).
- **Fix**: Created a centralized, reusable animated widget [`biometric_scan_hud.dart`](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/widgets/biometric_scan_hud.dart) carrying the Apple Face ID-inspired animated paint vectors. Integrated the new widget across the doctor patient lookup, pharmacist dashboard, pharmacist dispense verification, and emergency identifier overlays.
- **Files**: [biometric_scan_hud.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/widgets/biometric_scan_hud.dart), [patient_lookup_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/doctor/presentation/screens/patient_lookup_screen.dart), [patient_emergency_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/emergency/presentation/screens/patient_emergency_screen.dart), [dispense_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/dispense_screen.dart), [pharmacist_dashboard_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/pharmacist/presentation/screens/pharmacist_dashboard_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-018: Flat, Plain Layouts on Patient Emergency & Doctor Patient Record Views
- **Symptom**: Emergency medical profile screen and doctor patient record screen looked plain, with solid flat card outlines, basic text demographics labels, and raw action buttons.
- **Root Cause**: Screens relied on basic rows/columns of texts and outline containers without high-fidelity card grids or modern UI accents.
- **Fix**: Redesigned both screens: implemented a premium dual-ring avatar, colorful category chips, red-gradient blood group indicators, a grid of individual metric cards for demographics, and high-fidelity gradient-filled action capsules carrying tap/inkwell feedback.
- **Files**: [emergency_data_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/emergency/presentation/screens/emergency_data_screen.dart), [patient_record_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/doctor/presentation/screens/patient_record_screen.dart)
- **Resolved**: 2026-07-14

### 🟢 KI-019: Plain Static Background Splash & Missing Brand App Icon
- **Symptom**: The launcher icon and launch screen rendered a static image or generic logo.
- **Root Cause**: The custom animated zoom-reveal splash screen overlay and correct brand assets from the CareSync design system were not integrated into CareSyncMain.
- **Fix**: Ported the X-style zoom-reveal animation widget [`splash_reveal_overlay.dart`](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/widgets/splash_reveal_overlay.dart), integrated it above the root router layout in `app.dart`, and re-coded `splash_screen.dart` to trigger the reveal. Configured `flutter_launcher_icons.yaml` and re-generated launcher resources for Android/iOS.
- **Files**: [app.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/app.dart), [splash_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/screens/splash_screen.dart), [splash_reveal_overlay.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/widgets/splash_reveal_overlay.dart), [flutter_launcher_icons.yaml](file:///Users/zen/Documents/GitHub/CareSyncMain/flutter_launcher_icons.yaml)
- **Resolved**: 2026-07-14

### 🟢 KI-020: Splash Screen Hang and Prescription Screen Compile Errors
- **Symptom**: The application got stuck on the splash screen indefinitely at launch, and compilation errors were encountered on patient widgets and screens.
- **Root Cause**:
  1. An unhandled exception during database/storage operations in the session restoration flow (`AuthController.restoreSession`) was not caught by the splash screen initialization loop (`_checkAuthAndNavigate`), causing the navigation callbacks to never be triggered and the overlay to block the screen.
  2. The custom biometric verification and setup check helper functions were hardcoded stubs returning `false`, causing incorrect initialization outcomes.
  3. Patient medical history and prescription card screens had import path and visibility modifiers errors preventing clean compilation.
- **Fix**:
  1. Added try-catch blocks to `_checkAuthAndNavigate` in `splash_screen.dart` and `restoreSession` in `auth_controller.dart` to fail-safe log and fallback to the role selection page.
  2. Implemented `isBiometricAlreadyEnabled` and `_needsBiometricSetup` in `auth_controller.dart` to check against storage tokens and the backend `registered_devices` table.
  3. Corrected import path in `medical_history_screen.dart` and instantiated the public wrapper class in `prescription_card.dart`.
- **Files**: [splash_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/shared/presentation/screens/splash_screen.dart), [auth_controller.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/services/auth_controller.dart), [medical_history_screen.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/presentation/screens/medical_history_screen.dart), [prescription_card.dart](file:///Users/zen/Documents/GitHub/CareSyncMain/lib/features/patient/presentation/widgets/prescription_card.dart)
- **Resolved**: 2026-07-15

---

## How to Add an Entry

Use this format:
```
### 🟢 KI-001: Short Title
- **Symptom**: What was observed.
- **Root Cause**: Why it happened.
- **Fix**: What was changed.
- **Files**: Affected files.
- **Resolved**: 2026-07-14
```

Never delete old entries — change the status emoji instead.
