# System Architecture & Subsystem Workflows 🏗️

This document describes the high-level architecture of the CareSync ecosystem and details the cross-subsystem workflows.

---

## 1. High-Level Ecosystem Architecture

CareSync is designed around a three-tier architecture that bridges client applications with secure authentication, database access controls, and custom ML-powered biometric recognition:

```mermaid
flowchart TB
    subgraph ClientTier [Client Tier - Flutter App]
        App[Flutter Client App]
        local_auth[Local Biometric Auth SDK]
    end

    subgraph ApiTier [API & Services Gateways]
        EdgeFunc[Supabase Edge Functions]
        FastAPI[FastAPI Biometric API]
    end

    subgraph DataTier [Storage & Persistence Tier]
        SupaAuth[Supabase Auth]
        SupaDb[(Supabase PostgreSQL + pgvector)]
        SupaStorage[(Supabase Storage Buckets)]
    end

    %% Client Interactions
    App -->|Local Auth Pin/Face ID| local_auth
    App -->|HTTPS / GraphQL / WS| SupaDb
    App -->|HTTPS Storage Requests| SupaStorage
    App -->|HTTPS REST Auth| SupaAuth
    App -->|HTTPS Custom API Calls| FastAPI
    App -->|HTTPS QR Emergency Page| EdgeFunc

    %% API Interactions
    FastAPI -->|Service Role Access| SupaDb
    FastAPI -->|Fetch Encrypted Docs| SupaStorage
    EdgeFunc -->|Query Demographics| SupaDb
```

### Components Summary

1. **Flutter Mobile Client**: Operates as a single cross-platform application configured with role-based UI screens for Patients, Doctors, Pharmacists, and First Responders. Incorporates local storage encryption using `flutter_secure_storage` and local biometric guards using the `local_auth` SDK.
2. **FastAPI Biometrics API**: A self-hosted Python microservice that handles computational tasks: face extraction via RetinaFace, landmark mapping via MediaPipe Face Mesh, quality score gates, and 512-dimension vector embedding generation via ArcFace. It directly queries Supabase for vector comparison and maintains simple memory buffers to accelerate scans.
3. **Supabase Core**:
   - **Auth**: Authenticates identities and maps JWT payloads.
   - **PostgreSQL**: Implements strict Row-Level Security (RLS) policies and hosts biometric vectors using the `pgvector` extension.
   - **Storage Buckets**: Stores private KYC documents, avatars, and attachments.
4. **Supabase Edge Functions (`emergency`)**: Serve responsive HTML pages displaying crucial medical information for emergency responders scanning the offline patient QR code.

---

## 2. Core Subsystem Workflows

Here are the detailed workflow diagrams tracing cross-subsystem requests.

### A. Emergency "Break Glass" access (Biometric Lookup & Manual QR)

This workflow enables first responders to bypass patient credentials to access vitals during life-threatening incidents.

```mermaid
sequenceDiagram
    autonumber
    actor Responder as Emergency Responder
    participant App as Responder App Screen
    participant CustomBio as CustomBiometricService
    participant BioAPI as FastAPI Biometrics API
    participant DB as Supabase PostgreSQL
    participant EF as Supabase Edge Functions

    alt Scenario A: Scanner Identifies Patient Face (Cloud Biometric Scan)
        Responder->>App: Launch Camera Scan
        App->>CustomBio: Capture Frame
        CustomBio->>BioAPI: POST /identify (image bytes)
        Note over BioAPI: MediaPipe pose calculation<br/>ArcFace embedding generation
        BioAPI->>DB: RPC: match_patient_by_face_consensus(embedding)
        DB-->>BioAPI: Match found: patient_id, full_name, qr_code_id
        Note over BioAPI: python checks consensus scoring & margin gap
        BioAPI-->>CustomBio: returns best candidate + similarity confidence
        CustomBio-->>App: Display Identified Patient Name & ID
        Responder->>App: Confirm Emergency Access Request
        App->>DB: Insert into emergency_access_logs (patient_id, accessed_by)
        Note over DB: trigger stores immutable log<br/>updates temporary_access permission
        DB-->>App: Grant decrypted view tokens (15-min TTL)
        App->>DB: Fetch patient medical vitals & conditions
        DB-->>App: Return Decrypted Demographics & Vitals
        App-->>Responder: Display vital charts and allergies
    else Scenario B: Responder Scans Secure QR Code Offline
        Responder->>App: Scan Offline Patient QR code
        Note over App: QR payload contains symmetric-encrypted JSON
        alt Responder is Online
            App->>EF: Navigate to https://<ref>.supabase.co/functions/v1/emergency?id=qr_uuid
            EF->>DB: Record emergency access log
            EF->>DB: Query patient critical conditions
            DB-->>EF: Return public allergies & contacts
            EF-->>Responder: Render emergency HTML page in browser
        else Responder is Offline
            App->>App: Decrypt payload using preloaded static keys
            App-->>Responder: Display offline decrypted vitals locally
        end
    end
```

### B. Prescription Life-Cycle (Doctor -> Database -> Pharmacist)

Illustrates doctor signature generation, safety checks, and pharmacist dispensing operations.

```mermaid
sequenceDiagram
    autonumber
    actor Doc as Doctor
    actor Pharm as Pharmacist
    participant App as Flutter Mobile App
    participant DB as Supabase PostgreSQL
    participant PDF as PdfService

    Doc->>App: Search and Select Patient Profile
    App->>DB: Fetch Patient historical records
    DB-->>App: Return history
    Doc->>App: Add Medication and Dosages
    Note over App: Riverpod triggers SafetyAlert validator<br/>(calculates DDI and allergy clashes)
    alt Clash Found
        App-->>Doc: Display Warning: "Active clash with chronic allergy!"
    end
    Doc->>App: Click "Sign and Submit"
    App->>App: Trigger local biometric guard (local_auth)
    Note over App: Prompt for fingerprint / Face ID
    App-->>Doc: Local biometric verified
    App->>PDF: Generate signed PDF prescription
    Note over PDF: Embed Base64 signature and SHA-256 hash
    App->>DB: Insert prescription + items with signature metadata
    DB-->>App: Confirm submission (Success)

    Note over Pharm: Patient arrives at Pharmacy
    Pharm->>App: Lookup patient prescription records
    App->>DB: Fetch prescription where status = 'active'
    DB-->>App: Return prescriptions + signatures
    Pharm->>App: Mark medicines as "Dispensed"
    App->>DB: Insert into dispensing_records
    DB->>DB: Trigger: update prescription_items set is_dispensed = true
    DB-->>App: Update complete
    App-->>Pharm: Dispensation logged successfully
```

### C. Know Your Customer (KYC) Verification Workflow

Details enrollment security before patient biometrics are activated.

```mermaid
sequenceDiagram
    autonumber
    actor Pat as Patient
    participant App as Flutter Client App
    participant Storage as Supabase Storage Buckets
    participant DB as Supabase PostgreSQL
    participant BioAPI as FastAPI Biometrics API

    Pat->>App: Enter Demographics (Name, DOB, ID Type)
    Pat->>App: Take Photo of ID Document & selfie
    App->>Storage: Upload ID to private 'kyc-documents' bucket
    Storage-->>App: Return file path
    App->>Storage: Upload Selfie to private 'kyc-documents' bucket
    Storage-->>App: Return file path
    App->>DB: RPC: submit_kyc_verification_secure(metadata, files)
    DB->>DB: Insert row status = 'pending'
    DB-->>App: Return KYC submission confirmation
    Note over DB: Administrator reviews document (manual or web admin panel)
    DB->>DB: Update kyc_verifications set status = 'approved'
    Note over Pat: Patient logs back into application
    App->>DB: Check KYC verification status
    DB-->>App: Return status = 'approved'
    App-->>Pat: Prompt to enroll Cloud Biometrics (Neutral, Left, Right poses)
    Pat->>App: Start Guided Camera capture
    Note over App: Capture Neutral frame
    App->>BioAPI: POST /enroll (userId, selfieUrl, poseLabel='neutral')
    BioAPI->>Storage: Download selfieUrl
    BioAPI->>BioAPI: Validate pose + liveness
    BioAPI->>BioAPI: Generate ArcFace embedding
    BioAPI->>DB: Insert to face_embeddings
    DB-->>BioAPI: Success
    BioAPI-->>App: Response Success
    Note over App: Repeat for Left and Right poses
    App->>DB: Update biometric_profiles set enrollment_status = 'verified'
    DB-->>App: Profile locked
    App-->>Pat: Biometric enrollment completed!
```
