FROM python:3.9-slim

# Install system dependencies for OpenCV and graphic/X11 bindings
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libgl1 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libxcb1 \
    libx11-xcb1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download models to cache directory to avoid long cold starts in Hugging Face
# DeepFace downloads RetinaFace and ArcFace weights to ~/.deepface/weights/
# Let's create the folder and we can download them on container start or build time
RUN mkdir -p /root/.deepface/weights && \
    python -c "import urllib.request; urllib.request.urlretrieve('https://github.com/serengil/deepface_models/releases/download/v1.0/retinaface.h5', '/root/.deepface/weights/retinaface.h5'); urllib.request.urlretrieve('https://github.com/serengil/deepface_models/releases/download/v1.0/arcface_weights.h5', '/root/.deepface/weights/arcface_weights.h5')"

COPY . .

# Expose Hugging Face default port
EXPOSE 7860

# Run Uvicorn on port 7860
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
