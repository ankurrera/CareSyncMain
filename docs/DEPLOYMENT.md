# Deployment & Infrastructure Guide 🚀

This document describes how to deploy the CareSync ecosystem, including Supabase backend migrations, the FastAPI Docker container, and Hugging Face Spaces deployments.

---

## 1. Local & Production Environment Variables

You must configure the `.env` file before executing builds.

| Key | Example / Default | Target Subsystem | Description |
| :--- | :--- | :--- | :--- |
| `SUPABASE_URL` | `https://xxxx.supabase.co` | Flutter & FastAPI | Project database API endpoint |
| `SUPABASE_ANON_KEY` | `eyJhbGciOi...` | Flutter & FastAPI | Anonymous client API access key |
| `SUPABASE_SERVICE_ROLE_KEY`| `eyJhbGciOi...` | FastAPI API | Database bypass key for backend lookup |
| `BIOMETRIC_API_URL` | `http://localhost:8000` | Flutter client | Target endpoint of Python server |
| `HF_TOKEN` | `hf_abcdefg12345` | FastAPI API | Bearer token verifying client requests |

---

## 2. Supabase Migrations Deployment

CareSync schema upgrades are managed via the Supabase CLI:

1. **Install Supabase CLI**:
   ```bash
   npm install -g supabase
   ```
2. **Link Project**:
   ```bash
   supabase link --project-ref YOUR_PROJECT_ID
   ```
3. **Apply Local Migrations**:
   The database migrations are located in `supabase/migrations/` and apply sequentially from `001_schema.sql` to `042_...`. Apply them using the CLI:
   ```bash
   supabase db push
   ```
4. **Deploy Edge Functions**:
   Deploy the `emergency` edge function:
   ```bash
   supabase functions deploy emergency
   ```

---

## 3. Biometrics API Containerization (Docker)

The `biometric_api` directory contains a multi-stage `Dockerfile` to build and run the Python microservice.

### Dockerfile Breakdown
The Dockerfile optimizes caching by pre-downloading neural weights during the image build:
```dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies for OpenCV and MediaPipe
RUN apt-get update && apt-get install -y \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy download script and download weights to cache during build
COPY download_models.py .
RUN python download_models.py

COPY . .

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Build & Run Commands
```bash
cd biometric_api
docker build -t caresync-biometric-api:latest .
docker run -d -p 8000:8000 --env-file ../.env caresync-biometric-api:latest
```

---

## 4. Hugging Face Spaces Deployment

You can host the biometric API in a Hugging Face Space using a Docker SDK:

### Step 1: Create a Space
1. Log into [huggingface.co](https://huggingface.co).
2. Go to **Spaces** → **Create new Space**.
3. Choose a name (e.g. `caresync-biometrics`).
4. Select **Docker** as the SDK, and select the **Blank** template.

### Step 2: Set Environment Variables
1. Inside your Space settings, navigate to **Variables and Secrets**.
2. Add these variables:
   - `SUPABASE_URL` (your project endpoint)
   - `SUPABASE_KEY` (service role token)
   - `HF_TOKEN` (your secret access API token)

### Step 3: Push Source Code
Push the contents of `biometric_api/` to the Hugging Face repository. The build process will compile the Dockerfile, download the model weights, and spin up Uvicorn.
```bash
git remote add hf https://huggingface.co/spaces/YOUR_USERNAME/YOUR_SPACE_NAME
git push hf main
```
The Space will automatically rebuild and start running.
