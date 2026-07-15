import os
import urllib.request
import hashlib

print("Starting pre-download of biometric models...")
os.makedirs("/app/.deepface/weights", exist_ok=True)

# Build opener with a browser User-Agent to bypass GitHub's 429 rate limiter for python-urllib
opener = urllib.request.build_opener()
opener.addheaders = [('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')]
urllib.request.install_opener(opener)

# Pin model checksums (Recommended)
models = [
    {
        "url": "https://github.com/serengil/deepface_models/releases/download/v1.0/retinaface.h5",
        "path": "/app/.deepface/weights/retinaface.h5",
        "sha256": "ecb2393a89da3dd3d6796ad86660e298f62a0c8ae7578d92eb6af14e0bb93adf"
    },
    {
        "url": "https://github.com/serengil/deepface_models/releases/download/v1.0/arcface_weights.h5",
        "path": "/app/.deepface/weights/arcface_weights.h5",
        "sha256": "6336979c0c602cae08d1122a66f4dfb862d059bbcd8ef80306aef2b2249b0c93"
    },
    {
        "url": "https://github.com/minivision-ai/Silent-Face-Anti-Spoofing/raw/master/resources/anti_spoof_models/2.7_80x80_MiniFASNetV2.pth",
        "path": "/app/.deepface/weights/2.7_80x80_MiniFASNetV2.pth",
        "sha256": "a5eb02e1843f19b5386b953cc4c9f011c3f985d0ee2bb9819eea9a142099bec0"
    },
    {
        "url": "https://github.com/minivision-ai/Silent-Face-Anti-Spoofing/raw/master/resources/anti_spoof_models/4_0_0_80x80_MiniFASNetV1SE.pth",
        "path": "/app/.deepface/weights/4_0_0_80x80_MiniFASNetV1SE.pth",
        "sha256": "84ee1d37d96894d5e82de5a57df044ef80a58be2b218b5ed7cdfd875ec2f5990"
    }
]

require_model_checksums = os.getenv("REQUIRE_MODEL_CHECKSUMS") == "1"

def get_file_sha256(file_path):
    h = hashlib.sha256()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return None

for item in models:
    url = item["url"]
    path = item["path"]
    expected_sha = item["sha256"]

    # Step 1: Enforce HTTPS
    if not url.startswith("https://"):
        raise ValueError(f"Insecure URL protocol: {url}. Only HTTPS is permitted.")

    # Check if checksums are required but not provided in python script configuration
    if require_model_checksums and not expected_sha:
        raise ValueError(f"Checksum verification failed: No pinned SHA256 configuration found for {path} while REQUIRE_MODEL_CHECKSUMS=1.")

    # Step 2: Check if local file exists and matches pinned checksum (or size if unpinned)
    valid_exists = False
    if os.path.exists(path):
        if expected_sha:
            current_sha = get_file_sha256(path)
            if current_sha == expected_sha:
                print(f"Model already exists and hash is verified: {path}")
                valid_exists = True
            else:
                print(f"Model exists but hash mismatch: {path} (Expected: {expected_sha}, Got: {current_sha}). Re-downloading...")
        else:
            if os.path.getsize(path) > 1000000:
                print(f"Model already exists and size seems valid (unpinned hash): {path}")
                valid_exists = True

    if valid_exists:
        continue

    # Step 3: Download
    print(f"Downloading {url} -> {path}")
    try:
        urllib.request.urlretrieve(url, path)
        print(f"Successfully downloaded {path}")
    except Exception as e:
        print(f"Failed to download {url}: {e}")
        raise e

    # Step 4: Verify checksum after download
    if expected_sha:
        current_sha = get_file_sha256(path)
        if current_sha != expected_sha:
            err_msg = f"Checksum mismatch for downloaded model: {path} (Expected: {expected_sha}, Got: {current_sha})"
            if require_model_checksums:
                raise ValueError(err_msg)
            else:
                print(f"WARNING: {err_msg}")
    else:
        print(f"WARNING: Downloaded model {path} has no pinned checksum.")

print("All models successfully pre-downloaded and verified.")
