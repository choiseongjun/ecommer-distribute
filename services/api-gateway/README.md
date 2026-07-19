# API Gateway

## 역할
- 라우팅: 요청을 적절한 서비스로 전달
- 인증/인가: JWT 토큰 검증
- 레이트 리밋: API 호출 제한
- 로드 밸런싱: 서비스 인스턴스 간 트래픽 분산
- 서킷 브레이커: 장애 전파 방지

## CAP 전략
- **AP (가용성 우선)**: 게이트웨이 장애 시 모든 요청이 실패하는 것을 방지

## 기술 스택
- Spring Cloud Gateway
- Spring Cloud Circuit Breaker (Resilience4j)
- Spring Cloud Consul (서비스 디스커버리)
- JWT (인증)

## 설정
```yaml
spring:
  cloud:
    gateway:
      routes:
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/orders/**
```

## 실행
```bash
./gradlew bootRun
```
