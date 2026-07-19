import urllib.request
import urllib.error
import json
import time
import concurrent.futures
import statistics

GATEWAY_URL = "http://localhost:8080"
TOTAL_REQUESTS = 100000
CONCURRENCY = 50

results = {
    "total": 0,
    "success": 0,
    "fallback": 0,
    "failed": 0,
    "latencies": [],
    "endpoints": {
        "/api/products": {"success": 0, "fallback": 0, "failed": 0, "latencies": []},
        "/api/users": {"success": 0, "fallback": 0, "failed": 0, "latencies": []},
        "/api/orders": {"success": 0, "fallback": 0, "failed": 0, "latencies": []}
    }
}

def send_request(endpoint, method="GET", payload=None):
    url = f"{GATEWAY_URL}{endpoint}"
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    data_bytes = json.dumps(payload).encode("utf-8") if payload else None
    
    start_time = time.time()
    try:
        req = urllib.request.Request(url, data=data_bytes, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=10) as response:
            latency = (time.time() - start_time) * 1000
            resp_body = response.read().decode("utf-8")
            status = response.status
            
            resp_json = json.loads(resp_body) if resp_body else {}
            if isinstance(resp_json, dict) and resp_json.get("status") == "fallback":
                return endpoint, "fallback", latency
            else:
                return endpoint, "success", latency
    except urllib.error.HTTPError as e:
        latency = (time.time() - start_time) * 1000
        return endpoint, "failed", latency
    except Exception as e:
        latency = (time.time() - start_time) * 1000
        return endpoint, "failed", latency

def run_load_test():
    print("==================================================", flush=True)
    print("Starting High-Concurrency EKS Stress Load Test", flush=True)
    print(f"Target Gateway: {GATEWAY_URL}", flush=True)
    print(f"Total Requests: {TOTAL_REQUESTS} | Concurrency: {CONCURRENCY}", flush=True)
    print("==================================================", flush=True)
    
    tasks = []
    # Build list of diverse endpoint requests
    for i in range(TOTAL_REQUESTS):
        mod = i % 4
        if mod == 0:
            tasks.append(("/api/products", "GET", None))
        elif mod == 1:
            tasks.append(("/api/users", "POST", {"email": f"load_user_{i}_{int(time.time())}@example.com", "password": "password123", "name": f"User {i}"}))
        elif mod == 2:
            tasks.append(("/api/users/1", "GET", None))
        else:
            tasks.append(("/api/orders", "POST", {"userId": 1, "productId": 1, "quantity": 2, "totalAmount": 199.98}))

    start_total = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
        futures = [executor.submit(send_request, ep, method, data) for ep, method, data in tasks]
        for future in concurrent.futures.as_completed(futures):
            ep, status, latency = future.result()
            
            # Map endpoint key
            base_ep = "/api/products" if "products" in ep else ("/api/users" if "users" in ep else "/api/orders")
            
            results["total"] += 1
            results[status] += 1
            results["latencies"].append(latency)
            
            results["endpoints"][base_ep][status] += 1
            results["endpoints"][base_ep]["latencies"].append(latency)
            
            if results["total"] % 100 == 0 or results["total"] == TOTAL_REQUESTS:
                cur_elapsed = time.time() - start_total
                cur_rps = results["total"] / cur_elapsed if cur_elapsed > 0 else 0
                pct = (results["total"] / TOTAL_REQUESTS) * 100
                print(f"Progress: {results['total']}/{TOTAL_REQUESTS} ({pct:.1f}%) | Speed: {cur_rps:.1f} req/s | Success: {results['success']} | Fallback: {results['fallback']} | Failed: {results['failed']}", flush=True)

    elapsed_total = time.time() - start_total
    rps = results["total"] / elapsed_total
    
    avg_latency = statistics.mean(results["latencies"]) if results["latencies"] else 0
    p95_latency = statistics.quantiles(results["latencies"], n=20)[18] if len(results["latencies"]) > 20 else avg_latency

    print("\n==================================================")
    print("HEAVY LOAD TEST RESULTS SUMMARY")
    print("==================================================")
    print(f"Total Test Time      : {elapsed_total:.2f} seconds")
    print(f"Requests Per Second  : {rps:.2f} RPS")
    print(f"Success Count (200)  : {results['success']} ({results['success']/results['total']*100:.1f}%)")
    print(f"Fallback Count (CB)  : {results['fallback']} ({results['fallback']/results['total']*100:.1f}%)")
    print(f"Failed Count (Err)   : {results['failed']} ({results['failed']/results['total']*100:.1f}%)")
    print(f"Average Latency      : {avg_latency:.2f} ms")
    print(f"P95 Latency          : {p95_latency:.2f} ms")
    
    print("\n--- Microservice Breakdown ---")
    for ep, data in results["endpoints"].items():
        ep_avg = statistics.mean(data["latencies"]) if data["latencies"] else 0
        print(f"[{ep}]")
        print(f"  Success: {data['success']} | Fallback: {data['fallback']} | Failed: {data['failed']}")
        print(f"  Avg Latency: {ep_avg:.2f} ms")

if __name__ == "__main__":
    try:
        run_load_test()
    except KeyboardInterrupt:
        print("\n\nLoad test stopped by user (Ctrl+C).")
