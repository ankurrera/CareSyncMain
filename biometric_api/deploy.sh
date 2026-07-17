#!/usr/bin/env bash
# ====================================================================
# Google Cloud Run Deployment Script for Biometric API
# ====================================================================

set -e

SERVICE_NAME="${SERVICE_NAME:-biometric-api}"
REGION="${REGION:-us-central1}"
MEMORY="${MEMORY:-4Gi}"
CPU="${CPU:-2}"
CONCURRENCY="${CONCURRENCY:-10}"

echo "===================================================================="
echo " Deploying ${SERVICE_NAME} to Google Cloud Run"
echo " Region: ${REGION} | CPU: ${CPU} | Memory: ${MEMORY}"
echo "===================================================================="

# Ensure gcloud CLI is authenticated and active
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed. Please install Google Cloud SDK."
    exit 1
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo "Error: No active GCP project configured. Run 'gcloud config set project <PROJECT_ID>'."
    exit 1
fi

echo "Building and submitting container image via Cloud Build..."
IMAGE_URI="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

gcloud builds submit --tag "${IMAGE_URI}" .

echo "Deploying container image to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
    --image "${IMAGE_URI}" \
    --platform managed \
    --region "${REGION}" \
    --allow-unauthenticated \
    --memory "${MEMORY}" \
    --cpu "${CPU}" \
    --concurrency "${CONCURRENCY}" \
    --timeout 300s \
    --set-env-vars DEEPFACE_HOME=/app

echo "===================================================================="
echo " Deployment Complete!"
echo " Service URL: $(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)')"
echo "===================================================================="
