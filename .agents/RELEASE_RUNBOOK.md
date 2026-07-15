# RELEASE RUNBOOK — CareSync

AI agents and release engineers MUST follow this checklist for every production release. Never submit builds to stores without completing all safety, compilation, and security checks.

---

## Pre-Release Validation Checklist

- [ ] Run `flutter analyze` and ensure there are ZERO warnings or errors.
- [ ] Run `flutter test` and ensure all unit/widget tests pass successfully.
- [ ] Check `.agents/KNOWN_ISSUES.md` for active blocker reports.
- [ ] Verify that no secrets, active `.env` files, or private keys are tracked by Git.
- [ ] Verify that Google Fonts allowRuntimeFetching is disabled (`GoogleFonts.config.allowRuntimeFetching = false`) for offline robustness.
- [ ] Ensure `APP_ENV=production` is set in the build parameters.

---

## Step 1 — Version & Build Number Bumps

Increment the version and build number in [pubspec.yaml](../pubspec.yaml):
```yaml
version: 1.0.0+X  # Increment build number (after the '+') monotonically
```

---

## Step 2 — DB Migrations Deployment

Verify database sync state and apply any outstanding migrations via the Supabase CLI:
```bash
supabase link --project-ref YOUR_PRODUCTION_PROJECT_ID
supabase db push
```

---

## Step 3 — Biometric Microservice Build & Rollout

If the backend biometrics API container has changes:
1. Rebuild the production container in `biometric_api/`:
   ```bash
   docker build -t caresync-biometric-api:latest biometric_api/
   ```
2. Push container to your GCP Cloud Run or staging registry.
3. If using Hugging Face spaces fallback, sync code:
   ```bash
   git remote add hf https://huggingface.co/spaces/YOUR_SPACE
   git push hf main
   ```

---

## Step 4 — Compile and Code Obfuscation

Compile production release packages with full Dart obfuscation and split debug symbols:

### Android AAB Build:
```bash
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --dart-define-from-file=.env.production
```

### iOS IPA Archive Build:
```bash
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/ios/outputs/symbols \
  --dart-define-from-file=.env.production
```

> [!IMPORTANT]
> Keep the generated `symbols` files in a safe location. They are required to symbolicate obfuscated stack traces from crash reporting services (e.g. Sentry, Firebase Crashlytics).

---

## Step 5 — Store Submission & Rollout

- **Android Play Store**: Upload the signed `.aab` file to Google Play Console. Start with a 10% staged rollout to monitor for regressions.
- **iOS App Store**: Upload the archive via Xcode or Transporter. Verify TestFlight builds pass baseline QA before sending to App Review.
