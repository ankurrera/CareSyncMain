# Architecture Decision Records (ADR) 📝

This document records the architectural decisions made for the CareSync platform, including trade-offs and alternatives considered.

---

## ADR 001: Flutter for Mobile Client Application

### Status
Accepted

### Context
We needed a cross-platform client codebase that can compile to Android (for responders and doctors in hospital wards) and iOS (for consumer patient devices).

### Decision
Use Flutter (Dart) as the single core codebase framework.

### Consequences
* **Pros**: Single codebase to maintain, rich UI widgets, and stable native integrations via platform channels.
* **Cons**: Slightly larger binary sizes and overhead when calling native OS biometric SDKs.

---

## ADR 002: Supabase for Backend-as-a-Service (BaaS)

### Status
Accepted

### Context
We needed rapid database creation, robust user authorization controls, realtime messaging capabilities for doctor-patient chats, and storage buckets for KYC document validation.

### Decision
Adopt Supabase (PostgreSQL, Auth, Realtime, and Storage).

### Consequences
* **Pros**: Built-in support for Row-Level Security (RLS) policies, easy schema migrations, and native pgvector support.
* **Cons**: Custom complex transactions require writing PL/pgSQL functions (RPCs) rather than standard application code.

---

## ADR 003: FastAPI for Biometrics API

### Status
Accepted

### Context
Image parsing, landmark mapping, and convolutional neural network evaluations (ArcFace) require Python's ML ecosystem. These operations are computationally heavy and should be kept separate from the database layer.

### Decision
Implement a self-hosted FastAPI microservice running Uvicorn.

### Consequences
* **Pros**: Isolation of neural network pipelines from database operations, high performance, and rapid routing.
* **Cons**: Requires managing a separate service API, token checks, and environment configurations.

---

## ADR 004: ArcFace + pgvector for Facial Identification

### Status
Accepted

### Context
First responders need to identify unconscious patients using face recognition. This requires matching a query photo against registered patient face vectors.

### Decision
Generate 512-dimension vector embeddings using the ArcFace model, and query them in PostgreSQL using the pgvector extension and an HNSW cosine distance index.

### Consequences
* **Pros**: Quick lookups (<50ms) using HNSW indices, high matching accuracy, and database-level similarity lookups.
* **Cons**: Cosine distance calculation is sensitive to lighting and head pose, requiring additional pose validation layers.

---

## ADR 005: Multi-Pose Enrollment & Consensus Matching

### Status
Accepted

### Context
Single-pose facial identification is highly sensitive to head turns, which are common when responders scan patients.

### Decision
Enroll patients using three poses (Neutral, Left turn, Right turn). During search lookups, evaluate matching candidates across all enrolled poses and calculate a consensus similarity score.

### Consequences
* **Pros**: High matching reliability at different angles and robust spoofing prevention.
* **Cons**: Multi-pose enrollment takes longer for the user and requires more database storage space.
