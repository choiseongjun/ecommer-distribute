# Product Service

## 역할
- 상품 정보 관리
- 상품 검색
- 재고 관리

## CAP 전략
- **AP (가용성 우선)**: 높은 읽기 성능과 가용성
- Cassandra + Elasticsearch

## 기술 스택
- Spring Boot
- Spring Data Cassandra
- Elasticsearch
- Spring Cloud Consul

## 데이터 모델
```cql
CREATE TABLE products (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL,
    stock INT,
    category TEXT,
    created_at TIMESTAMP
);
```

## 실행
```bash
./gradlew bootRun
```
