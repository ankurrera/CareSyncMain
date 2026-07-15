# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CareSync is a biometric-authenticated medical logging and e-prescription app serving four roles: Patient, Doctor, Pharmacist, and First Responder. It has three subsystems:

1. **Flutter client** (`lib/`) — Dart 3.7+, Riverpod state management, GoRouter navigation.
2. **Supabase backend** (`supabase/`) — Postgres with RLS on all tables, Auth, Realtime chat, Storage, and a Deno Edge Function (`supabase/functions/emergency/`) that renders the emergency QR-code web page.
3. **Biometric API** (`biometric_api/`) — a self-hosted Python FastAPI microservice (single ~2000-line `main.py`) doing ArcFace face embeddings (via DeepFace) and MediaPipe pose analysis. Endpoints: `/enroll`, `/verify_id`, `/identify`, `/analyze_frame`. Embeddings are 512-d vectors stored in Supabase pgvector; identification uses centroid matching with consensus scoring.

## Commands

### Flutter client (repo root)
```bash
flutter pub get                     # install deps
flutter run                         # run the app (requires .env, see below)
flutter analyze                     # lint (flutter_lints defaults)
flutter test                        # all tests
flutter test test/ocr_service_test.dart   # single test file
flutter pub run build_runner build --delete-conflicting-outputs   # regen freezed/json/riverpod code
```
Code generation is required after editing any file with a `part '*.g.dart'` or `part '*.freezed.dart'` directive (models in `lib/features/*/models/`, generated providers in `lib/features/*/providers/`).

### Biometric API (`biometric_api/`)
```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python download_models.py           # fetch ArcFace/MediaPipe models (one-time)
uvicorn main:app --reload --port 8000
python -m unittest test_biometric_pipeline.py   # tests
```

### Database
`supabase/*.sql` are numbered migrations (001–041) applied in order via the Supabase SQL editor — there is no CLI migration tooling. New schema changes get the next number. Deploy the edge function with `supabase functions deploy emergency`.

## Environment

The Flutter app loads `.env` from the repo root **as a Flutter asset** (declared in `pubspec.yaml`), so a missing `.env` breaks the build, not just runtime. Copy `.env.example`:
```
SUPABASE_URL, SUPABASE_ANON_KEY, BIOMETRIC_API_URL (http://localhost:8000 for local), HF_TOKEN (optional)
```
Access is centralized in `lib/core/config/env_config.dart`.

## Architecture

### Flutter layout
- `lib/main.dart` → loads dotenv, initializes Supabase, wraps app in `ProviderScope`.
- `lib/routing/app_router.dart` — all GoRouter routes; role-based redirect logic lives here. Route path constants in `route_names.dart`.
- `lib/services/` — plain service classes (not feature-scoped): `auth_controller.dart`, `supabase_service.dart`, `custom_biometric_service.dart` (HTTP client for the FastAPI service, with retry/cancel-token logic), `encryption_service.dart`, `pdf_service.dart`, `vitals_service.dart`, `chat_service.dart`, `emergency_access_service.dart`, audit services, and `wearables/` (health-platform adapter, offline sync queue, conflict resolver).
- `lib/features/<role>/` — feature-first: `presentation/screens`, `presentation/widgets`, `providers`, `models` per role (`patient`, `doctor`, `pharmacist`, `emergency`, `family`, `auth`, `biometric`, `shared`).
- `lib/features/shared/` — cross-role screens (chat), models (`appointment.dart`, `chat.dart`), and `services/ocr_service.dart` (ML Kit text recognition for prescription scanning).

### Biometric flow (the core differentiator)
Two independent layers:
- **Local** (`local_auth` + `flutter_secure_storage`): device biometric lock; sessions auto-lock after 15 min inactivity (`app_lifecycle_service.dart`).
- **Cloud** (`custom_biometric_service.dart` → FastAPI): multi-pose face enrollment produces embeddings stored in pgvector. First responders identify unconscious patients by face; matches release critical medical data and are written to tamper-proof audit logs (DB triggers block UPDATE/DELETE on `biometric_access_logs`).

### Emergency access paths
1. QR code → Supabase Edge Function renders patient emergency data as HTML (`web/emergency.html` fallback).
2. Offline QR decryption (symmetric key, `encryption_service.dart`).
3. Face identification via the biometric API.

### Security invariants
- Every table has RLS; several migrations exist solely to fix RLS recursion/visibility bugs (015, 021, 031, 041) — check existing policies before adding queries that join `profiles`.
- Emergency/biometric access must be audit-logged; audit tables are append-only.

## Conventions (from CONTRIBUTING.md)

- Conventional Commits: `feat(scope): ...`, `fix(scope): ...`, etc.
- Branching: `main` (production, PR-only) ← `develop` (integration) ← `feature/*`; `hotfix/*` cut from `main`.

## Documentation

Detailed docs live in `docs/` — `DOCUMENTATION_INDEX.md` is the map. Most relevant when working here: `DATABASE.md` (schema/ER/RPCs), `BIOMETRIC_SYSTEM.md` (embedding math, consensus scoring), `API_REFERENCE.md` (biometric API + edge function payloads), `TROUBLESHOOTING.md` (known build/DB issues).
