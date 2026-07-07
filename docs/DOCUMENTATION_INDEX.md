# CareSync — Documentation Index 📂

Welcome to the CareSync Engineering & Product Documentation Index. This repository houses a highly secure, HIPAA-compliant biometric medical logging and e-prescription platform.

To enable smooth developer onboarding and provide complete architectural transparency, the documentation is divided into specialized modules:

---

## 🏗️ Architecture & Systems

* **[System Architecture](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/SYSTEM_ARCHITECTURE.md)**  
  Overall ecosystem map, cross-system data flows, and end-to-end Mermaid sequence diagrams for core actions.
* **[Flutter Client Architecture](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/FLUTTER_ARCHITECTURE.md)**  
  State management with Riverpod, GoRouter layout routing, custom widgets, local session guards, and theme styling guidelines.
* **[Backend Microservice Architecture](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/BACKEND_ARCHITECTURE.md)**  
  FastAPI server structure, model preloading strategies, and API request caching mechanisms.
* **[Biometric Engine Deep-Dive](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/BIOMETRIC_SYSTEM.md)**  
  ArcFace embedding vectors, MediaPipe landmark pose estimations, liveness thresholds, and consensus verification formulas.

---

## 💾 Data & Interoperability

* **[Database Schema Audit](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/DATABASE.md)**  
  ER diagram, table schemas, indexes (pgvector/HNSW), constraints, database triggers, and RPC functions.
* **[API Endpoint Reference](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/API_REFERENCE.md)**  
  Request/Response JSON payloads, HTTP headers, authentication schemas, and query parameters for FastAPI and Supabase Edge functions.

---

## 🛡️ Security, QA & DevOps

* **[Security & HIPAA Compliance](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/SECURITY.md)**  
  JWT structures, Postgres RLS policies, symmetric QR encryption, biometric access logging triggers, and threat modeling.
* **[Deployment & Infrastructure](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/DEPLOYMENT.md)**  
  Docker container setups, environment variable checklists, Supabase CLI operations, and Hugging Face deployment guidelines.
* **[Developer Onboarding Guide](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/DEVELOPER_GUIDE.md)**  
  Local environment initialization, SDK setup, and code building processes.
* **[Testing & Verification Plan](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/TESTING.md)**  
  Running Flutter unit/widget tests and python-based biometric validation suites.

---

## 🗒️ Guidelines, Decisions & FAQ

* **[Contributor Guidelines (CONTRIBUTING.md)](file:///Users/zen/Documents/GitHub/CareSyncMain/CONTRIBUTING.md)**  
  Branching strategies, conventional commits, code review checklists, and standards.
* **[Architecture Decision Records (ADR)](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/ADR.md)**  
  Detailed ADR reports covering technology choices (FastAPI, ArcFace, pgvector, Flutter, Supabase).
* **[Troubleshooting Handbook](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/TROUBLESHOOTING.md)**  
  Solutions to common build, database, model download, and runtime errors.
* **[Ecosystem Roadmap](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/ROADMAP.md)**  
  Planned features, integrations, and milestones.
* **[Frequently Asked Questions (FAQ)](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/FAQ.md)**  
  Answers to typical operator, developer, and compliance questions.
* **[Changelog](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/CHANGELOG.md)**  
  Version history, database migration additions, and refactoring history.
* **[Documentation Audit Report](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/DOCUMENTATION_AUDIT_REPORT.md)**  
  Final audit verifying documentation integrity and link consistency.

---

## 📂 Archived & Historical Documents

The following documents represent historical design layouts, change notes, and verification logs preserved in the archive:

* **[Add Prescription Summary](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/ADD_PRESCRIPTION_SUMMARY.md)**  
  Historical implementation summary of the patient input screen.
* **[Biometric Authorization Design](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/BIOMETRIC_AUTHORIZATION_IMPLEMENTATION.md)**  
  Historical system architecture details for biometrics.
* **[Biometric Fix Notes](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/BIOMETRIC_FIX_SUMMARY.md)**  
  Notes on startup preloading optimizations.
* **[Biometric Accuracy Tests](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/BIOMETRIC_FIX_TESTING.md)**  
  QA tests list for matching times.
* **[Biometric Flow Diagrams](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/BIOMETRIC_FLOW_DIAGRAM.md)**  
  ASCII layout flowchart for local authentication.
* **[Biometric KYC Refactoring Notes](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/BIOMETRIC_KYC_REFACTORING.md)**  
  Steps list of Refactoring.
* **[Implementation Checklist Completion](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/IMPLEMENTATION_COMPLETE.md)**  
  Release verification report.
* **[Ecosystem Integration Summary](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/IMPLEMENTATION_SUMMARY.md)**  
  Historical development summary sheet.
* **[Biometrics Core Delivery Summary](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/IMPLEMENTATION_SUMMARY_BIOMETRIC.md)**  
  Historical feature summary list.
* **[Final Launch Summary](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/IMPLEMENTATION_SUMMARY_FINAL.md)**  
  Technical validation log.
* **[Input Fields Design Fix](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/INPUT_FIELD_FIX_SUMMARY.md)**  
  Summary of text input field alignment fixes.
* **[KYC 2FA Security Specs](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/KYC_2FA_IMPLEMENTATION.md)**  
  Security protocols outline of 2FA.
* **[Medication Dosage Forms Calculation](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/MEDICATION_FORM_FLOW.md)**  
  ASCII diagram explaining automatic quantity calculations.
* **[Prescription Parsing Hotfixes](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/PRESCRIPTION_DATA_FIX_SUMMARY.md)**  
  Hotfix logs mapping medical parsing.
* **[Prescription Quick Reference Cheat Sheet](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/PRESCRIPTION_FIX_QUICK_REFERENCE.md)**  
  Validation constants reference cheat sheet.
* **[E-Prescription Core Launch Guide](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/PRESCRIPTION_IMPLEMENTATION_GUIDE.md)**  
  Checklist mapping database schema columns additions.
* **[Doctor Signatures Screens Design](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/PRESCRIPTION_SCREEN_IMPLEMENTATION.md)**  
  Screen structures details for signing.
* **[Core PR Log 1](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/PR_SUMMARY.md)**  
  Core development pull request overview notes.
* **[Core PR Log 2](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/PR_SUMMARY_PRESCRIPTION_FIX.md)**  
  Prescriptions hotfix pull request overview notes.
* **[Layout Overflows Design Fix](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/RENDERFLEX_OVERFLOW_FIX.md)**  
  Layout fixes and expanded drop-down parameters details.
* **[Patient UI Screens Visual Layout](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/SCREEN_STRUCTURE.md)**  
  ASCII layout structure drawings for forms.
* **[Supabase Base BaaS Integration Setup](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/SUPABASE_SETUP.md)**  
  Original step-by-step setup guides for storage and database.
* **[RenderFlex Visual Diagrams](file:///Users/zen/Documents/GitHub/CareSyncMain/docs/archive/VISUAL_EXPLANATION.md)**  
  ASCII flow explaining crossAxisAlignment row alignment error fixes.
