#!/usr/bin/env python3
"""
대용량 샘플 데이터 생성 스크립트
쿼리 튜닝을 위한 복잡한 데이터 생성
"""

import random
import string
from datetime import datetime, timedelta
import psycopg2
from psycopg2 import pool
import uuid

# 데이터베이스 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'microservices',
    'user': 'admin',
    'password': 'admin123'
}

# 데이터 생성 설정
NUM_USERS = 10000
NUM_CATEGORIES = 50
NUM_BRANDS = 100
NUM_PRODUCTS = 50000
NUM_ORDERS = 100000
NUM_REVIEWS = 200000
NUM_PRODUCT_VIEWS = 500000
NUM_SEARCH_LOGS = 300000

# 랜덤 데이터 생성 함수
def random_string(length=10):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def random_email():
    return f"{random_string(8)}@{random.choice(['gmail', 'naver', 'daum', 'yahoo'])}.com"

def random_phone():
    return f"010-{random.randint(1000, 9999)}-{random.randint(1000, 9999)}"

def random_date(start_year=2020, end_year=2024):
    start_date = datetime(start_year, 1, 1)
    end_date = datetime(end_year, 12, 31)
    return start_date + timedelta(days=random.randint(0, (end_date - start_date).days))

def random_korean_name():
    first_names = ['김', '이', '박', '최', '정', '강', '조', '윤', '장', '임']
    last_names = ['민수', '서연', '도현', '수빈', '준호', '지원', '예진', '현우', '민지', '성민']
    return random.choice(first_names) + random.choice(last_names)

# 데이터베이스 연결
connection_pool = psycopg2.pool.SimpleConnectionPool(
    1, 10, **DB_CONFIG
)

def get_connection():
    return connection_pool.getconn()

def release_connection(conn):
    connection_pool.putconn(conn)

# 카테고리 데이터 생성
def generate_categories():
    conn = get_connection()
    cur = conn.cursor()
    
    categories = []
    main_categories = ['전자제품', '의류', '식품', '가구', '스포츠', '도서', '뷰티', '반려동물']
    
    for i, main_cat in enumerate(main_categories):
        cur.execute("""
            INSERT INTO categories (name, parent_id, level, sort_order)
            VALUES (%s, NULL, 1, %s)
            RETURNING id
        """, (main_cat, i * 10))
        parent_id = cur.fetchone()[0]
        categories.append(parent_id)
        
        # 서브 카테고리
        for j in range(5):
            sub_cat = f"{main_cat}-{random_string(5)}"
            cur.execute("""
                INSERT INTO categories (name, parent_id, level, sort_order)
                VALUES (%s, %s, 2, %s)
                RETURNING id
            """, (sub_cat, parent_id, j))
            categories.append(cur.fetchone()[0])
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {len(categories)} categories")
    return categories

# 브랜드 데이터 생성
def generate_brands():
    conn = get_connection()
    cur = conn.cursor()
    
    brand_names = [
        'Samsung', 'LG', 'Apple', 'Sony', 'Nike', 'Adidas', 'Uniqlo', 'Muji',
        'Ikea', 'Daiso', 'Olive Young', 'Lush', 'The Body Shop', 'Innisfree'
    ]
    
    brand_ids = []
    for i in range(NUM_BRANDS):
        if i < len(brand_names):
            name = brand_names[i]
        else:
            name = f"Brand-{random_string(8)}"
        
        cur.execute("""
            INSERT INTO brands (name, description, country, is_premium)
            VALUES (%s, %s, %s, %s)
            RETURNING id
        """, (name, f"{name} description", random.choice(['Korea', 'USA', 'Japan', 'Germany']), random.choice([True, False])))
        brand_ids.append(cur.fetchone()[0])
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {len(brand_ids)} brands")
    return brand_ids

# 사용자 데이터 생성
def generate_users(category_ids, brand_ids):
    conn = get_connection()
    cur = conn.cursor()
    
    user_ids = []
    tiers = ['BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND']
    
    for i in range(NUM_USERS):
        email = random_email()
        name = random_korean_name()
        tier = random.choices(tiers, weights=[50, 30, 15, 4, 1])[0]
        status = random.choice(['ACTIVE', 'INACTIVE', 'SUSPENDED'])
        
        cur.execute("""
            INSERT INTO users (email, password, name, phone, birth_date, gender, status, tier, registration_date, last_login)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            email, 'hashed_password', name, random_phone(), 
            random_date(1980, 2005), random.choice(['M', 'F', 'OTHER']),
            status, tier, random_date(2020, 2024), random_date(2023, 2024)
        ))
        user_id = cur.fetchone()[0]
        user_ids.append(user_id)
        
        # 주소 생성
        for j in range(random.randint(1, 3)):
            cur.execute("""
                INSERT INTO user_addresses (user_id, address_type, postal_code, address1, address2, city, is_default)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                user_id, random.choice(['HOME', 'OFFICE', 'OTHER']),
                f"{random.randint(10000, 99999)}",
                f"{random_string(10)} street", f"Apt {random.randint(1, 999)}",
                random.choice(['Seoul', 'Busan', 'Daegu', 'Incheon', 'Gwangju']),
                j == 0
            ))
        
        # 선호도 생성
        cur.execute("""
            INSERT INTO user_preferences (user_id, preferred_categories, price_range_min, price_range_max)
            VALUES (%s, %s, %s, %s)
        """, (
            user_id, random.sample(category_ids, random.randint(1, 5)),
            random.randint(10000, 50000), random.randint(100000, 1000000)
        ))
        
        if i % 1000 == 0:
            conn.commit()
            print(f"Generated {i} users...")
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {len(user_ids)} users")
    return user_ids

# 상품 데이터 생성
def generate_products(category_ids, brand_ids):
    conn = get_connection()
    cur = conn.cursor()
    
    product_ids = []
    product_names = [
        'Smartphone', 'Laptop', 'Headphones', 'T-shirt', 'Jeans', 'Sneakers',
        'Watch', 'Backpack', 'Sunglasses', 'Camera', 'Tablet', 'Monitor'
    ]
    
    for i in range(NUM_PRODUCTS):
        sku = f"SKU-{random_string(12)}"
        name = f"{random.choice(product_names)} {random_string(5)}"
        category_id = random.choice(category_ids)
        brand_id = random.choice(brand_ids) if random.random() > 0.3 else None
        price = random.randint(10000, 500000)
        status = random.choice(['ACTIVE', 'INACTIVE', 'OUT_OF_STOCK'])
        
        cur.execute("""
            INSERT INTO products (sku, name, description, category_id, brand_id, price, 
                                compare_at_price, stock_quantity, status, is_featured)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            sku, name, f"Description for {name}", category_id, brand_id,
            price, int(price * 1.2), random.randint(0, 1000), status, random.random() > 0.9
        ))
        product_id = cur.fetchone()[0]
        product_ids.append(product_id)
        
        # 이미지 생성
        for j in range(random.randint(1, 5)):
            cur.execute("""
                INSERT INTO product_images (product_id, image_url, alt_text, is_primary)
                VALUES (%s, %s, %s, %s)
            """, (
                product_id, f"https://example.com/images/{product_id}_{j}.jpg",
                f"Image {j} for {name}", j == 0
            ))
        
        if i % 5000 == 0:
            conn.commit()
            print(f"Generated {i} products...")
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {len(product_ids)} products")
    return product_ids

# 리뷰 데이터 생성
def generate_reviews(user_ids, product_ids):
    conn = get_connection()
    cur = conn.cursor()
    
    for i in range(NUM_REVIEWS):
        user_id = random.choice(user_ids)
        product_id = random.choice(product_ids)
        rating = random.randint(1, 5)
        
        cur.execute("""
            INSERT INTO product_reviews (product_id, user_id, rating, title, content, is_verified_purchase)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            product_id, user_id, rating,
            f"{'Great' if rating >= 4 else 'Average' if rating == 3 else 'Poor'} product",
            f"This product is {'amazing' if rating >= 4 else 'okay' if rating == 3 else 'disappointing'}. " +
            f"I {'love' if rating >= 4 else 'like' if rating == 3 else 'hate'} it!",
            random.random() > 0.3
        ))
        
        if i % 10000 == 0:
            conn.commit()
            print(f"Generated {i} reviews...")
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {NUM_REVIEWS} reviews")

# 주문 데이터 생성
def generate_orders(user_ids, product_ids):
    conn = get_connection()
    cur = conn.cursor()
    
    order_ids = []
    statuses = ['PENDING', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'REFUNDED']
    
    for i in range(NUM_ORDERS):
        user_id = random.choice(user_ids) if random.random() > 0.1 else None
        order_number = f"ORD-{datetime.now().strftime('%Y%m%d')}-{random.randint(100000, 999999)}"
        status = random.choices(statuses, weights=[10, 20, 30, 30, 5, 5])[0]
        
        # 주문 상품
        num_items = random.randint(1, 5)
        selected_products = random.sample(product_ids, min(num_items, len(product_ids)))
        subtotal = 0
        
        cur.execute("""
            INSERT INTO orders (order_number, user_id, status, subtotal, total_amount, created_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (order_number, user_id, status, 0, 0, random_date(2023, 2024)))
        order_id = cur.fetchone()[0]
        order_ids.append(order_id)
        
        for product_id in selected_products:
            cur.execute("SELECT price FROM products WHERE id = %s", (product_id,))
            price = cur.fetchone()[0]
            quantity = random.randint(1, 3)
            total = price * quantity
            subtotal += total
            
            cur.execute("""
                INSERT INTO order_items (order_id, product_id, product_name, quantity, unit_price, total_price)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (order_id, f"Product {product_id}", quantity, price, total))
        
        # 주문 총액 업데이트
        total_amount = subtotal * 1.1  # 10% tax
        cur.execute("""
            UPDATE orders SET subtotal = %s, total_amount = %s WHERE id = %s
        """, (subtotal, total_amount, order_id))
        
        if i % 10000 == 0:
            conn.commit()
            print(f"Generated {i} orders...")
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {len(order_ids)} orders")

# 제품 조회 이력 생성
def generate_product_views(product_ids, user_ids):
    conn = get_connection()
    cur = conn.cursor()
    
    for i in range(NUM_PRODUCT_VIEWS):
        product_id = random.choice(product_ids)
        user_id = random.choice(user_ids) if random.random() > 0.3 else None
        session_id = str(uuid.uuid4()) if user_id is None else None
        
        cur.execute("""
            INSERT INTO product_views (product_id, user_id, session_id, view_duration)
            VALUES (%s, %s, %s, %s)
        """, (product_id, user_id, session_id, random.randint(10, 300)))
        
        if i % 50000 == 0:
            conn.commit()
            print(f"Generated {i} product views...")
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {NUM_PRODUCT_VIEWS} product views")

# 검색 이력 생성
def generate_search_logs(user_ids):
    conn = get_connection()
    cur = conn.cursor()
    
    search_queries = [
        'smartphone', 'laptop', 'wireless headphones', 'running shoes',
        'winter jacket', 'gaming monitor', 'mechanical keyboard', 'wireless mouse',
        'smart watch', 'tablet', 'camera', 'backpack', 'sunglasses'
    ]
    
    for i in range(NUM_SEARCH_LOGS):
        user_id = random.choice(user_ids) if random.random() > 0.4 else None
        session_id = str(uuid.uuid4()) if user_id is None else None
        query = random.choice(search_queries) + (" " + random_string(5) if random.random() > 0.7 else "")
        
        cur.execute("""
            INSERT INTO search_logs (user_id, session_id, search_query, results_count)
            VALUES (%s, %s, %s, %s)
        """, (user_id, session_id, query, random.randint(0, 100)))
        
        if i % 50000 == 0:
            conn.commit()
            print(f"Generated {i} search logs...")
    
    conn.commit()
    cur.close()
    release_connection(conn)
    print(f"Created {NUM_SEARCH_LOGS} search logs")

# 메인 실행 함수
def main():
    print("Starting sample data generation...")
    
    try:
        print("Generating categories...")
        category_ids = generate_categories()
        
        print("Generating brands...")
        brand_ids = generate_brands()
        
        print("Generating users...")
        user_ids = generate_users(category_ids, brand_ids)
        
        print("Generating products...")
        product_ids = generate_products(category_ids, brand_ids)
        
        print("Generating reviews...")
        generate_reviews(user_ids, product_ids)
        
        print("Generating orders...")
        generate_orders(user_ids, product_ids)
        
        print("Generating product views...")
        generate_product_views(product_ids, user_ids)
        
        print("Generating search logs...")
        generate_search_logs(user_ids)
        
        print("Sample data generation completed successfully!")
        
    except Exception as e:
        print(f"Error generating sample data: {e}")
        raise
    finally:
        connection_pool.closeall()

if __name__ == "__main__":
    main()
