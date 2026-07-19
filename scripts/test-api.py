import urllib.request
import urllib.error
import json
import time

def make_request(url, method='GET', data=None):
    req = urllib.request.Request(url, method=method)
    req.add_header('Content-Type', 'application/json')
    req.add_header('Accept', 'application/json')
    
    body = None
    if data is not None:
        body = json.dumps(data).encode('utf-8')
        
    try:
        with urllib.request.urlopen(req, data=body, timeout=5) as response:
            resp_data = response.read().decode('utf-8')
            status_code = response.status
            return status_code, json.loads(resp_data) if resp_data else None
    except urllib.error.HTTPError as e:
        resp_data = e.read().decode('utf-8')
        try:
            err_json = json.loads(resp_data)
        except:
            err_json = resp_data
        return e.code, err_json
    except Exception as e:
        return 0, str(e)

def test_api():
    print("==================================================")
    print("Starting API Gateway & Microservices End-to-End Tests")
    print("Gateway URL: http://localhost:8080")
    print("==================================================")
    
    # 1. Test User Service (Create User)
    print("\n[Step 1] Creating a User...")
    user_data = {
        "email": f"test_user_{int(time.time())}@example.com",
        "password": "password123",
        "name": "Test User"
    }
    code, resp = make_request("http://localhost:8080/api/users", "POST", user_data)
    print(f"Response Code: {code}")
    print(f"Response: {json.dumps(resp, indent=2)}")
    if code != 200:
        print("[FAIL] Create user failed. Stopping tests.")
        return
        
    # Check if the response was fallback or real response
    if resp and resp.get("status") == "fallback":
        print("[FAIL] Route resolved to FALLBACK. User service might still be down.")
        return

    user_id = resp.get("id")
    print(f"[OK] User created successfully with ID: {user_id}")
    
    # 2. Test User Service (Get User)
    print(f"\n[Step 2] Retrieving User {user_id}...")
    code, resp = make_request(f"http://localhost:8080/api/users/{user_id}")
    print(f"Response Code: {code}")
    print(f"Response: {json.dumps(resp, indent=2)}")
    if code != 200:
        print("[FAIL] Retrieve user failed. Stopping tests.")
        return
    print("[OK] User retrieved successfully.")

    # 3. Test Product Service (Create Product)
    print("\n[Step 3] Creating a Product...")
    product_data = {
        "name": "Test Product",
        "description": "Test Description",
        "price": 99.99,
        "stock": 100,
        "category": "Electronics"
    }
    code, resp = make_request("http://localhost:8080/api/products", "POST", product_data)
    print(f"Response Code: {code}")
    print(f"Response: {json.dumps(resp, indent=2)}")
    if code != 200:
        print("[FAIL] Create product failed. Stopping tests.")
        return
        
    if resp and resp.get("status") == "fallback":
        print("[FAIL] Route resolved to FALLBACK. Product service might still be down.")
        return

    product_id = resp.get("id")
    print(f"[OK] Product created successfully with ID: {product_id}")

    # 4. Test Product Service (Get All Products)
    print("\n[Step 4] Retrieving Product List...")
    code, resp = make_request("http://localhost:8080/api/products")
    print(f"Response Code: {code}")
    print(f"Response: {json.dumps(resp, indent=2)}")
    if code != 200:
        print("[FAIL] Retrieve products failed. Stopping tests.")
        return
    print("[OK] Product list retrieved successfully.")

    # 5. Test Order Service (Create Order)
    print("\n[Step 5] Creating an Order...")
    order_data = {
        "userId": user_id,
        "productId": 1,
        "quantity": 2,
        "totalAmount": 199.98
    }
    code, resp = make_request("http://localhost:8080/api/orders", "POST", order_data)
    print(f"Response Code: {code}")
    print(f"Response: {json.dumps(resp, indent=2)}")
    if code != 200:
        print("[FAIL] Create order failed. Stopping tests.")
        return
        
    if resp and resp.get("status") == "fallback":
        print("[FAIL] Route resolved to FALLBACK. Order service might still be down.")
        return

    order_id = resp.get("id")
    print(f"[OK] Order created successfully with ID: {order_id}")

    # 6. Test Order Service (Get Order)
    print(f"\n[Step 6] Retrieving Order {order_id}...")
    code, resp = make_request(f"http://localhost:8080/api/orders/{order_id}")
    print(f"Response Code: {code}")
    print(f"Response: {json.dumps(resp, indent=2)}")
    if code != 200:
        print("[FAIL] Retrieve order failed.")
        return
    print("[OK] Order retrieved successfully.")
    
    print("\n==================================================")
    print("[SUCCESS] All API Gateway End-to-End Tests Passed Successfully!")
    print("==================================================")

if __name__ == "__main__":
    test_api()
