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

# Copy model downloader script and execute pre-downloads
ENV DEEPFACE_HOME=/app
COPY download_models.py .
RUN python download_models.py && \
    rm download_models.py && \
    chmod -R 777 /app/.deepface

COPY . .

# Expose Hugging Face default port
EXPOSE 7860

# Run Uvicorn on port 7860
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
