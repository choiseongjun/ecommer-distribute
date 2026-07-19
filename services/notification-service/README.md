# Notification Service

## 역할
- 이메일 발송
- SMS 발송
- 푸시 알림
- 알림 템플릿 관리

## CAP 전략
- **AP (가용성 우선)**: 알림 유실 방지
- Kafka + Redis

## 기술 스택
- Spring Boot
- Apache Kafka
- Redis
- Spring Cloud Consul

## 실행
```bash
./gradlew bootRun
```
