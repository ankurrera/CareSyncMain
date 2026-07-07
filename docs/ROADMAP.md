# CareSync Product & Tech Roadmap 🗺️

This document outlines planned improvements, research tracks, and security milestones for CareSync.

---

## 🎯 Short-Term Focus (Q3 2026 - Q4 2026)

### ⌚ 1. Wearables & Sensor Synchronization
* **Objective**: Stream realtime vitals (heart rate, SpO2, blood pressure) from WearOS and Apple Watch sensors.
* **Architecture**: Create background sync services (`wearables_service.dart`) that cache vitals logs locally and batch upload them to Supabase when stable network is restored.

### 🏥 2. HL7 FHIR Interoperability
* **Objective**: Export medical charts and e-prescriptions in the HL7 Fast Healthcare Interoperability Resources (FHIR) standard format.
* **Architecture**: Set up edge converters to translate PostgreSQL rows into standardized JSON structures, enabling integration with hospital Epic and Cerner networks.

---

## 🚀 Medium-Term Focus (Q1 2027 - Q2 2027)

### 🤖 3. On-Device Biometric Face Extraction
* **Objective**: Perform face alignment and embedding calculations directly on mobile devices (using TensorFlow Lite and MediaPipe on-device SDKs) to reduce backend hosting costs and enable offline biometric searches.
* **Architecture**: Compile the ArcFace model into a `.tflite` asset file and integrate it into the Flutter client app code.

### 🔑 4. Decoupled Symmetric Key Rotations
* **Objective**: Strengthen symmetric key security for the offline emergency QR cards.
* **Architecture**: Rotate GCM symmetric keys dynamically using short-lived secrets fetched from the database, moving away from static client keys.
