---
title: CareSync Biometrics
emoji: 🧬
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# CareSync Production Biometric API

A production-grade biometric face processing microservice with ArcFace, RetinaFace, OpenCV, and pgvector.

## Run Locally
```bash
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```
