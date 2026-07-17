FROM python:3.9-slim

# Set environment variables for non-interactive installs and Python unbuffering
ENV PYTHONUNBUFFERED=1 \
    DEEPFACE_HOME=/app \
    PORT=8080

# Install system dependencies for OpenCV and graphic/X11 bindings
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libgl1 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libxcb1 \
    libx11-xcb1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download DeepFace, ArcFace, and RetinaFace weights to prevent runtime latency
COPY download_models.py .
RUN python download_models.py && \
    rm download_models.py && \
    chmod -R 777 /app/.deepface

# Copy application source code
COPY . .

# Expose default port for Google Cloud Run / Container Environments
EXPOSE 8080

# Launch Uvicorn server with dynamic PORT evaluation
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
