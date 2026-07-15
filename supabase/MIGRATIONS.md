# CareSync Database Migrations Index

This index logs and documents all 51 sequential migration files in the `supabase/` directory. Use this document as the single source of truth for schema setup, upgrade guarantees, and dependency tracking.

---

## 1. Local Database Setup & Initialization

All database migrations are located in `supabase/` and applied sequentially from `001_schema.sql` to `052_sprint1_indexes.sql`. 

### Running Migrations

To apply migrations to a target database, run:
```bash
supabase db push
```

To reset the local database and re-apply all migrations sequentially from scratch:
```bash
supabase db reset
```

---

## 2. Migration Registry & Milestones

### Phase 1 — Core Patient & Doctor Schema (001 - 007)
- **001_schema.sql**: Creates primary base tables (`profiles`, `patients`, `doctors`, `pharmacists`, `prescriptions`, `prescription_items`, `dispensing_records`). Enforces baseline constraints.
- **002_schema_fix.sql**: Fixes schema references and references constraints between `profiles` and role-specific tables.
- **003_schema_fix_v2.sql**: Minor syntax fixes and constraint adjustments.
- **004_fix_profile_creation.sql**: Adjusts triggers that auto-create user profiles upon auth registration.
- **005_fix_profile_update.sql**: Adds update triggers ensuring profile modifications sync appropriately.
- **006_add_medication_fields.sql**: Adds metadata and instructions fields to prescription items.
- **007_migration_add_device_security.sql**: Adds device security binding tables.

### Phase 2 — KYC & Emergency Infrastructure (008 - 013)
- **008_kyc_schema.sql**: Enforces patient identity verification tables and RLS permissions.
- **009_emergency_access_schema.sql**: Establishes emergency QR code lookup and temporary first responder access windows.
- **010_vitals_schema.sql**: Adds deterministic-encrypted vitals logs (`vitals`).
- **011_messaging_schema.sql**: Secure chat messages schema.
- **012_appointments_schema.sql**: Booking schedules and status FSM slots.
- **013_patient_entered_prescriptions.sql**: Support for patients self-uploading historical paper prescriptions.

### Phase 3 — Authentication, Seed & Azure Biometrics (014 - 024)
- **014_seed_test_doctors.sql**: Inserts mock credentials for doctor roles.
- **015_fix_doctor_visibility.sql**: Allows patients to view doctor profiles.
- **016_azure_face_schema.sql**: Legacy structure for Azure face enrollment.
- **017_biometric_vector_schema.sql**: Upgrades face embeddings structure using `pgvector`.
- **018_multi_embedding_schema.sql**: Enables storing multiple poses (angles, smiles) per patient.
- **019_fix_qr_code_uuid.sql**: QR code primary key normalization.
- **020_merge_first_responder.sql**: Consolidation of emergency first responder validation policies.
- **021_fix_kyc_rls.sql**: Hardens RLS on `kyc_verifications`.
- **022_centroid_match_upgrade.sql**: Adds vector centroid functions to cluster face embeddings.
- **023_centroid_index_and_triggers.sql**: Adds performance indexes for high-speed multi-pose searches.
- **024_update_severity_check_constraint.sql**: Constraint updates.

### Phase 4 — Audits, Wearables, Real-time & Signatures (025 - 042)
- **025_emergency_access_logs_audit.sql**: Immutable emergency audit logger with RLS locks.
- **026_wearable_migration.sql**: Integrates smartwatch vital trackers.
- **027_biometric_core_schema.sql**: Restructures custom python biometric microservice API tables.
- **028_fix_chat_profile_lookup.sql**: Optimizes chat search queries.
- **029_enable_realtime_chat.sql**: Configures Supabase Realtime publication for secure chat.
- **030_update_messages_schema.sql**: Hardens chat encryption constraints.
- **031_fix_doctors_rls.sql**: Hardens RLS policies on the `doctors` table.
- **032_add_doctor_signature.sql**: Adds digital signature hashes.
- **033_add_biometric_model_version.sql**: Adds AI network architecture tag.
- **034_biometric_enterprise_upgrade.sql**: Adds multi-device registration metrics.
- **035_add_pose_angles_to_embeddings.sql**: Yaw/pitch/roll tracking.
- **036_biometric_session_versioning.sql**: Hardens session IDs to prevent replay.
- **037_add_missing_patient_columns.sql**: Fixes schema gaps.
- **038_fix_emergency_access_logs_patient_fk.sql**: Safe foreign key cascade behaviors.
- **039_kyc_secure_submit_rpc.sql**: Exposes `submit_kyc_secure` database transaction RPC.
- **040_vitals_emergency_rls.sql**: Permits temporary emergency bypass reads to vitals.
- **041_fix_pharmacists_rls.sql**: Restricts pharmacists write access.
- **042_remove_deprecated_features.sql**: Drops legacy columns.

### Phase 5 — Production Hardening & Sprint 1 Indexes (043 - 052)
- **043_biometric_emergency_hardening.sql**: High-security offline logging synchronization.
- **045_enable_realtime_appointments_prescriptions.sql**: Live real-time status sync.
- **046_production_hardening_fsm_and_transactions.sql**: Enforces appointment FSM states, prescription immutability, and dispensing transaction blocks.
- **047_fix_profiles_insert_rls.sql**: Fixes signup RLS insertion loops.
- **048_fix_pharmacists_rls_compat.sql**: Backwards compatibility for pharmacist profiles.
- **049_fix_pharmacists_rls_individual.sql**: Refines pharmacist access levels.
- **050_production_hardening_rls_and_privacy.sql**: Restricts patient medical data to owner and authorized providers.
- **051_production_cert_fixes.sql**: Solves multi-role lookup issues and final production certification leaks.
- **052_sprint1_indexes.sql**: Optimized indexes for paginated lookups and search sorting.

---

## 3. Safe Idempotency Guide

| Migration | Safe to re-run? | Non-idempotent elements | Recovery Action |
|---|---|---|---|
| `001` - `042` | Yes, mostly | Uses `CREATE TABLE IF NOT EXISTS` and `CREATE OR REPLACE FUNCTION`. | `supabase db reset` if core column types mismatch. |
| `046` | Partial | Alters columns / adds constraints. | Can throw error if constraints exist. |
| `050` | Yes | RLS policies dropped and re-created safely. | Safe. |
| `051` | Yes | Modifies profiles security policies. | Safe. |
| `052` | Yes | Uses `CREATE INDEX IF NOT EXISTS`. | Safe. |
