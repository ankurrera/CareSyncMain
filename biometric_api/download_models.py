import os
import urllib.request

print("Starting pre-download of biometric models...")
os.makedirs("/app/.deepface/weights", exist_ok=True)

# Build opener with a browser User-Agent to bypass GitHub's 429 rate limiter for python-urllib
opener = urllib.request.build_opener()
opener.addheaders = [('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36')]
urllib.request.install_opener(opener)

urls = [
    ("https://github.com/serengil/deepface_models/releases/download/v1.0/retinaface.h5", "/app/.deepface/weights/retinaface.h5"),
    ("https://github.com/serengil/deepface_models/releases/download/v1.0/arcface_weights.h5", "/app/.deepface/weights/arcface_weights.h5"),
    ("https://github.com/minivision-ai/Silent-Face-Anti-Spoofing/raw/master/resources/anti_spoof_models/2.7_80x80_MiniFASNetV2.pth", "/app/.deepface/weights/2.7_80x80_MiniFASNetV2.pth"),
    ("https://github.com/minivision-ai/Silent-Face-Anti-Spoofing/raw/master/resources/anti_spoof_models/4_0_0_80x80_MiniFASNetV1SE.pth", "/app/.deepface/weights/4_0_0_80x80_MiniFASNetV1SE.pth")
]

for url, path in urls:
    if os.path.exists(path) and os.path.getsize(path) > 1000000:
        print(f"Model already exists and is valid: {path}")
        continue
    print(f"Downloading {url} -> {path}")
    try:
        urllib.request.urlretrieve(url, path)
        print(f"Successfully downloaded {path}")
    except Exception as e:
        print(f"Failed to download {url}: {e}")
        raise e

print("All models successfully pre-downloaded.")
