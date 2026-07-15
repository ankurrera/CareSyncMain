# CareSync Environment Management Guide

CareSync supports complete separation of environment configurations across Development, Staging, and Production tiers. This guide documents configuration schema, switches, and deployment builds.

---

## 1. Environment Config Matrix

| Parameter | Development | Staging | Production |
|---|---|---|---|
| **APP_ENV** | `development` | `staging` | `production` |
| **SUPABASE_URL** | `http://localhost:54321` | Staging Supabase URL | Prod Supabase URL |
| **BIOMETRIC_API_URL** | `http://localhost:8000` | Staging Microservice API | GCP Cloud Run URL |
| **FALLBACK_BIOMETRIC_API_URL**| `http://localhost:8000` | Staging Hugging Face Space | Prod Hugging Face Space |
| **HF_TOKEN** | (none / mock) | Staging space read token | Prod space read token |

---

## 2. Setting Up Environment Files

The root repository contains templates for each configuration tier:

- **Local Dev / Fallback**: Copy [.env.development.example](../.env.development.example) to `.env` in the root.
- **Staging**: Copy [.env.staging.example](../.env.staging.example) to `.env.staging`.
- **Production**: Copy [.env.production.example](../.env.production.example) to `.env.production`.

---

## 3. Switching Environments in Local Development

### Option A: Dotenv File Swap (Default)
Overwrite the root `.env` file with the contents of the target environment:
```bash
cp .env.development.example .env
```
Start the application normally via VS Code/Android Studio run configs or `flutter run`.

### Option B: Build-time Dart Defines
Avoid file copy dependencies by passing configuration values directly at build time:
```bash
flutter run --dart-define-from-file=.env.staging
```
This injects parameters compile-time. The `EnvConfig` class prioritizes `--dart-define` parameters over variables loaded from the root `.env` file.

---

## 4. CI/CD Pipeline Injection

For secure builds in CI/CD pipelines (GitHub Actions, GitLab CI, Codemagic), do not commit `.env` files. Instead:

1. Configure pipeline Secrets for target environment keys.
2. In the build script, generate the target config dynamically before compiling:
   ```bash
   cat <<EOF > .env.production
   APP_ENV=production
   SUPABASE_URL=${PROD_SUPABASE_URL}
   SUPABASE_ANON_KEY=${PROD_SUPABASE_ANON_KEY}
   BIOMETRIC_API_URL=${PROD_BIOMETRIC_API_URL}
   FALLBACK_BIOMETRIC_API_URL=${PROD_FALLBACK_BIOMETRIC_API_URL}
   HF_TOKEN=${PROD_HF_TOKEN}
   EOF
   ```
3. Compile using:
   ```bash
   flutter build appbundle --release --dart-define-from-file=.env.production
   ```
