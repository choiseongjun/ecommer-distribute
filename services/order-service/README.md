# Order Service

## 역할
- 주문 생성 및 관리
- 주문 상태 추적
- 결제 처리 연동

## CAP 전략
- **CP (일관성 우선)**: 트랜잭션 일관성 필수
- PostgreSQL + Kafka 이벤트 소싱

## 기술 스택
- Spring Boot
- Spring Data JPA
- PostgreSQL
- Apache Kafka
- Spring Cloud Consul

## 데이터 모델
```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

## 실행
```bash
./gradlew bootRun
```
