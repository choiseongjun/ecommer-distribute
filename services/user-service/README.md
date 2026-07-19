# User Service

## 역할
- 사용자 관리 (회원가입, 로그인, 프로필)
- 인증 토큰 발급
- 사용자 정보 조회

## CAP 전략
- **CP (일관성 우선)**: 사용자 데이터 일관성이 중요
- PostgreSQL + Redis 캐시

## 기술 스택
- Spring Boot
- Spring Data JPA
- PostgreSQL
- Redis
- Spring Cloud Consul

## 데이터 모델
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 실행
```bash
./gradlew bootRun
```
