# Frequently Asked Questions (FAQ) ❓

This document provides answers to common questions about the CareSync platform.

---

## 🔒 Security & HIPAA Compliance

### Q1: Is CareSync HIPAA-compliant?
* **Answer**: Yes. CareSync implements technical safeguards required by HIPAA:
  - Row-Level Security (RLS) protects all database tables.
  - Vitals and medical records are encrypted.
  - Biometric logins automatically auto-lock sessions after 15 minutes of inactivity.
  - Database access logs are immutable and compile a complete audit trail.

### Q2: Can a responder reverse engineer a patient's face from the biometric vectors?
* **Answer**: No. ArcFace outputs a 512-dimension floating-point vector representing facial structure. This vector is a one-way representation; it cannot be reverse engineered to recreate the original image of the patient's face.

---

## 🧬 Biometrics & Landmarking

### Q3: Why does CareSync use multi-pose enrollment?
* **Answer**: Multi-pose enrollment captures different head angles (Neutral, Left, Right). This improves match accuracy when responders take photos in emergency settings, where it may not be possible to capture a straight, well-lit portrait.

### Q4: How is spoofing (photo attacks) prevented?
* **Answer**: We run a liveness check using the Silent-Face-Anti-Spoofing library (PyTorch backend). The algorithm analyzes depth maps and surface textures to verify the source image is a real, 3D face rather than a 2D screen or print.

---

## 🛠️ Developer Setup & Integration

### Q5: How do I run the biometric API without a GPU?
* **Answer**: By default, the Python server runs on the CPU if a CUDA GPU is not detected. This is sufficient for development and testing, though inferences may take slightly longer (around 300-600ms on CPU vs. <100ms on GPU).
