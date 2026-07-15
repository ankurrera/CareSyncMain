import os
import sys
import time
import json
import random
import threading
import concurrent.futures
import urllib.request
from urllib.error import HTTPError
import numpy as np
from supabase import create_client, Client

# Resolve environment variables
env_path = "/Users/zen/Documents/GitHub/CareSyncMain/.env"
if os.path.exists(env_path):
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                os.environ[k.strip()] = v.strip()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
BIOMETRIC_API_URL = "http://127.0.0.1:8000"
HF_TOKEN = os.getenv("HF_TOKEN")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ============================================================================
# 1. DATABASE PGVECTOR STRESS TESTER
# ============================================================================
def run_db_stress_test(scale_sizes=[100, 500]):
    """
    Stress tests pgvector search by populating the database with mock vectors,
    measuring search execution times, and clean up afterwards.
    """
    print("\n=======================================================")
    print("PHASE 5 — DATABASE PGVECTOR STRESS TEST")
    print("=======================================================")
    
    # 1. Fetch an existing patient ID from the database
    print("Fetching an existing patient ID for stress testing...")
    try:
        pat_res = supabase.from_("patients").select("id").limit(1).execute()
        if not pat_res.data:
            print("No existing patients in the database. Cannot run database stress test.")
            return
        temp_patient_id = pat_res.data[0]["id"]
        print(f"Using patient ID: {temp_patient_id}")
    except Exception as e:
        print(f"Failed to fetch patient ID: {e}")
        return

    try:
        for size in scale_sizes:
            print(f"\nBenchmarking at scale: {size} embeddings...")
            
            # Generate random 512-dimension vectors
            mock_embeddings = []
            for i in range(size):
                v = np.random.randn(512)
                v = (v / np.linalg.norm(v)).tolist() # L2 normalize
                mock_embeddings.append({
                    "patient_id": temp_patient_id,
                    "embedding": v,
                    "pose_label": f"mock_stress_{i}_{size}",
                    "quality_score": 0.95
                })
                
            # Insert in chunks to avoid HTTP payload limits
            chunk_size = 100
            t0 = time.time()
            for i in range(0, size, chunk_size):
                supabase.from_("patient_embeddings").insert(mock_embeddings[i:i+chunk_size]).execute()
            t1 = time.time()
            print(f"Populated {size} vectors in {t1 - t0:.2f} seconds.")
            
            # Run test searches (10 trials)
            query_vector = np.random.randn(512)
            query_vector = (query_vector / np.linalg.norm(query_vector)).tolist()
            
            latencies = []
            for trial in range(10):
                t_start = time.time()
                res = supabase.rpc("match_patient_by_face_multi", {
                    "query_embedding": query_vector,
                    "max_distance": 0.45,
                    "match_limit": 10
                }).execute()
                t_end = time.time()
                latencies.append((t_end - t_start) * 1000)
                
            avg_lat = sum(latencies) / len(latencies)
            p95_lat = np.percentile(latencies, 95)
            print(f"HNSW Centroid DB Search latency stats ({size} records):")
            print(f"  Average: {avg_lat:.2f} ms")
            print(f"  P95:     {p95_lat:.2f} ms")
            print(f"  Min/Max: {min(latencies):.2f} ms / {max(latencies):.2f} ms")
            
            # Clean up embeddings inserted in this batch
            supabase.from_("patient_embeddings").delete().eq("patient_id", temp_patient_id).like("pose_label", f"mock_stress_%_{size}").execute()
            print(f"Cleaned up {size} embeddings.")
            
    except Exception as e:
        print(f"Error during stress test execution: {e}")
    finally:
        # Final cleanup safety check
        print("Running final safety cleanup of mock_stress_ embeddings...")
        try:
            supabase.from_("patient_embeddings").delete().eq("patient_id", temp_patient_id).like("pose_label", "mock_stress_%").execute()
            print("Cleanup completed successfully.")
        except Exception as e:
            print(f"Error during final cleanup: {e}")

# ============================================================================
# 2. CONCURRENT LOAD TESTER
# ============================================================================
def call_identify_api(image_bytes):
    """
    Makes a single multipart POST request to the /identify endpoint.
    """
    url = f"{BIOMETRIC_API_URL}/identify"
    
    # Construct multipart request manually
    boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
    headers = {
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Authorization": f"Bearer {HF_TOKEN}"
    }
    
    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="scan.jpg"\r\n'
        f"Content-Type: image/jpeg\r\n\r\n"
    ).encode("utf-8") + image_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")
    
    t0 = time.time()
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as res:
            status = res.status
            response_body = res.read().decode("utf-8")
            res_data = json.loads(response_body)
    except HTTPError as e:
        status = e.code
        response_body = e.read().decode("utf-8")
        res_data = None
    except Exception as e:
        status = 0
        response_body = str(e)
        res_data = None
    t1 = time.time()
    
    return {
        "latency_ms": (t1 - t0) * 1000,
        "status": status,
        "success": status == 200,
        "response": res_data,
        "raw_response": response_body
    }

def run_concurrent_load_test(image_bytes, concurrency_levels=[1, 5, 10]):
    """
    Simulates concurrent requests to /identify to stress test microservice queue times.
    """
    print("\n=======================================================")
    print("PHASE 6 — CONCURRENT LOAD TEST")
    print("=======================================================")
    
    for level in concurrency_levels:
        print(f"\nLaunching {level} concurrent requests...")
        
        latencies = []
        success_count = 0
        failures = []
        
        t0 = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=level) as executor:
            futures = [executor.submit(call_identify_api, image_bytes) for _ in range(level)]
            for fut in concurrent.futures.as_completed(futures):
                res = fut.result()
                latencies.append(res["latency_ms"])
                if res["success"]:
                    success_count += 1
                else:
                    failures.append(res["status"])
        t1 = time.time()
        
        total_time_ms = (t1 - t0) * 1000
        avg_lat = sum(latencies) / len(latencies)
        p95_lat = np.percentile(latencies, 95)
        
        print(f"Results for {level} concurrent users:")
        print(f"  Total Time:   {total_time_ms:.2f} ms")
        print(f"  Success Rate: {success_count}/{level} ({(success_count/level)*100:.1f}%)")
        print(f"  Average RTT:  {avg_lat:.2f} ms")
        print(f"  P95 RTT:      {p95_lat:.2f} ms")
        if failures:
            print(f"  Failure HTTP Statuses: {failures}")

# ============================================================================
# 3. ACCURACY & FAILURE TESTING
# ============================================================================
def run_failure_scenarios():
    """
    Tests sending corrupted, empty, or misaligned inputs to verify system recovery.
    """
    print("\n=======================================================")
    print("PHASE 7 — FAILURE & QUALITY ROBUSTNESS TESTING")
    print("=======================================================")
    
    # Scenario A: Corrupted empty file
    print("Scenario A: Uploading empty byte stream...")
    res = call_identify_api(b"")
    print(f"  Status: {res['status']}, Response: {res['raw_response']}")
    
    # Scenario B: Invalid non-image data
    print("Scenario B: Uploading plain text file (invalid image)...")
    res = call_identify_api(b"this is plain text and not an image file")
    print(f"  Status: {res['status']}, Response: {res['raw_response']}")
    
    # Scenario C: Valid solid color block (No Face Detected check)
    print("Scenario C: Uploading solid gray block (no face in image)...")
    import cv2
    img = np.ones((500, 500, 3), dtype=np.uint8) * 128
    _, enc = cv2.imencode(".jpg", img)
    res = call_identify_api(enc.tobytes())
    print(f"  Status: {res['status']}, Response: {res['raw_response']}")

if __name__ == "__main__":
    # Fetch a reference image from storage to use for concurrency test
    print("Fetching reference face scan from kyc-documents bucket...")
    try:
        image_bytes = supabase.storage.from_("kyc-documents").download(
            "9be3e6e4-355b-47e0-947f-654ebfbc587d/selfie_smile-1783285304372.jpg"
        )
    except Exception as e:
        print(f"Failed to fetch reference scan: {e}. Generating dummy image for benchmark...")
        import cv2
        img = np.ones((500, 500, 3), dtype=np.uint8) * 128
        _, enc = cv2.imencode(".jpg", img)
        image_bytes = enc.tobytes()
        
    run_db_stress_test([100, 500])
    run_concurrent_load_test(image_bytes, [1, 5, 10])
    run_failure_scenarios()
