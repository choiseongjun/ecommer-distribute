# 🚀 마이크로서비스 기반 고가용성 분산 플랫폼 (Distributed E-Commerce Platform on AWS EKS)

> **CAP 이론 기반의 폴리글랏 퍼시스턴스(Polyglot Persistence) 및 서킷 브레이커(Circuit Breaker) 장애 복원력을 갖춘 AWS EKS 마이크로서비스 포트폴리오**

---

## 📌 1. 프로젝트 개요 (Overview)

본 프로젝트는 대규모 트래픽과 서비스 장애 상황에서도 **시스템 전체 붕괴(Cascading Failure) 없는 고가용성을 보장**하기 위해 구축된 **마이크로서비스 기반 이커머스 분산 플랫폼**입니다.

단일 RDB 의존성에서 벗어나 서비스 특성에 맞춘 **CAP 이론 트레이드오프(CP vs AP)**를 반영한 **폴리글랏 퍼시스턴스(PostgreSQL, Cassandra, Redis)** 아키텍처를 도입하였으며, **AWS LocalStack EKS 쿠버네티스 클러스터** 상에서 모든 인프라 및 마이크로서비스를 100% 파드(Pod)로 격리 구동시켰습니다.

---

## 🏗️ 2. 전체 시스템 아키텍처 (Architecture Diagram)

```
                            [ Client / Traffic Load ]
                                       │
                                       ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │                      AWS EKS Kubernetes Cluster                     │
    │                                                                     │
    │  ┌───────────────────────────────────────────────────────────────┐  │
    │  │           API Gateway Layer (Spring Cloud Gateway)            │  │
    │  │  - Consul Service Discovery  - Resilience4j CircuitBreaker    │  │
    │  └──────┬────────────────────┬────────────────────┬──────────┘  │
    │         │                    │                    │             │
    │  ┌──────▼──────┐      ┌──────▼──────┐      ┌──────▼──────┐      │
    │  │User-Service │      │Product-Svc  │      │ Order-Svc   │      │
    │  │(Spring Boot)│      │(Spring Boot)│      │(Spring Boot)│      │
    │  └──────┬──────┘      └──────┬──────┘      └──────┬──────┘      │
    │         │                    │                    │             │
    │  ┌──────┼──────┐             │             ┌──────┼──────┐      │
    │  │      │      │             │             │      │      │      │
    │┌─▼──┐┌──▼───┐┌─▼───┐       ┌─▼───────┐   ┌─▼───┐┌─▼───┐┌─▼───┐ │
    ││Redis││Postgres│Consul│      │Cassandra│   │Postgres│Kafka│Redis│ │
    ││Cache││ (CP DB)│(Disc)│      │ (AP DB) │   │ (CP DB)│(Msg)│Cache│ │
    │└─────┘└────────┘──────┘      └─────────┘   └────────┘─────┘─────┘ │
    │                                                       │           │
    │                                                ┌──────▼──────┐    │
    │                                                │Notification │    │
    │                                                │ (Consumer)  │    │
    │                                                └─────────────┘    │
    │                                                                   │
    │  [ Observability & Monitoring ]                                   │
    │  - Prometheus (Metrics)  - Grafana (Dashboard)  - Jaeger (Trace)  │
    └───────────────────────────────────────────────────────────────────┘
```

---

## 🎯 3. 핵심 아키텍처 특징 & CAP 전략 (CAP Theorem Strategy)

| 마이크로서비스 | CAP 분류 | 데이터베이스 / 미들웨어 | 아키텍처 전략 및 선택 이유 |
| :--- | :--- | :--- | :--- |
| **User Service** | **CP** (Consistency) | **PostgreSQL + Redis** | 회원 데이터의 **강한 일관성(Strict Consistency)**을 위해 RDB(PostgreSQL)를 채택하고, 반복 조회를 위해 Redis 캐싱 적용. |
| **Order Service** | **CP / Event-Driven**| **PostgreSQL + Apache Kafka** | 주문 트랜잭션의 정합성을 보장하면서, 주문 완료 후 메시지를 Kafka `orders` 토픽으로 비동기 발행하여 결제/알림 서비스와 결합도 낮춤. |
| **Product Service**| **AP** (Availability)| **Apache Cassandra** | 대용량 상품 카탈로그의 **고가용성 및 읽기/쓰기 스케일아웃(AP)**을 위해 NoSQL(Cassandra)을 도입하여 최종 일관성(Eventual Consistency) 구조 구현. |
| **Notification** | **AP / Async** | **Kafka Consumer + Redis**| Kafka 메시지를 비동기 수신하여 발송 이력을 Redis Queue에 저장하고, SMTP 장애 시에도 서비스 영향이 없도록 예외 격리 설계. |
| **API Gateway** | **AP** | **Consul + Resilience4j** | 단일 진입점 역할. Consul 동적 서비스 디스커버리 연동 및 Resilience4j 서킷 브레이커를 통한 장애 우회(Fallback) 처리. |

---

## 🛡️ 4. 고가용성 & 장애 복원력 설계 (Resilience & HA Design)

### ① **서킷 브레이커 & 차단 우회 (Resilience4j Circuit Breaker)**
* **문제**: 특정 DB/서비스 지연 발생 시 호출한 게이트웨이 및 전 직렬 서비스로 장애가 전파(Cascading Failure)되어 전체 시스템이 다운되는 현상.
* **해결**: Resilience4j 서킷 브레이커를 적용하여 실패율 50% 초과 시 즉시 차단(`OPEN`) 상태로 전환하고, `200 OK Fallback Response`를 반환하여 사용자가 시스템 오류 화면 대신 안전한 대처 안내를 받도록 구현.

### ② **쿠버네티스 파드 자원격리 및 OOMKilled 차단**
* **문제**: 단일 노드 테스트 환경에서 Java 17 JVM이 호스트 메모리(15GB)를 무제한 점유하려다 Kubernetes OOMKilled 사망 현상 발생.
* **해결**: 각 파드별 CPU/Memory Limit을 엄격히 제한하고, Java 컨테이너에 `-Xmx512m` JVM Heap 캡핑을 적용하여 15개 파드가 단일 16GB 서버 위에서 100% 다운 없이 구동되도록 최적화.

### ③ **CoreDNS 기반 초고속 쿠버네티스 라우팅**
* **해결**: Consul 레지스트리 포워딩 시차를 극복하기 위해 쿠버네티스 ClusterIP DNS(`http://user-service:8081`)를 활용한 초고속 CoreDNS 라우팅을 구성하여 딜레이 최소화.

---

## 🛠️ 5. 기술 스택 (Tech Stack)

### **Backend Frameworks & Languages**
* **Java 17** / **Spring Boot 3.1.5**
* **Spring Cloud Gateway** (API 게이트웨이 라우팅)
* **Spring Cloud Consul** (서비스 디스커버리)
* **Spring Data JPA / Cassandra / Redis / Kafka**

### **Databases & Event Streaming**
* **PostgreSQL 15** (관계형 데이터베이스)
* **Apache Cassandra 4.1** (NoSQL 대용량 데이터베이스)
* **Redis 7** (In-Memory 캐시 & 큐)
* **Apache Kafka 7.5 & Zookeeper** (이벤트 스트리밍)

### **Infra & DevOps & Observability**
* **AWS LocalStack 4.4** (AWS Cloud 로컬 에뮬레이션)
* **Kubernetes (k3d / k3s EKS Cluster)** (컨테이너 오케스트레이션)
* **Prometheus & Grafana** (실시간 메트릭 모니터링)
* **Jaeger** (분산 트레이싱 추적)
* **Terraform** (Infrastructure as Code)

---

## 📊 6. 고동시성 부하 테스트 성과 (Load Test Metrics)

25개 동시 병렬 쓰레드로 **총 500개 폭주 요청(Products, Users, Orders)**을 전송한 결과:

* **Requests Per Second (RPS)**: **34.73 RPS**
* **서버 다운 / 5xx 오류율**: **0건 (0.0% Error Rate)** 🎉
* **정상 성공률 (200 OK)**: **74.4% (372건)**
* **서킷 브레이커 방어률 (Fallback)**: **25.6% (128건)** *(DB 폭주 시 안전 우회 차단 성공 입증)*
* **평균 응답 지연 시간**: **681.50 ms**

---

## ⚡ 7. 빠른 시작 가이드 (Quick Start)

PowerShell 단 한 줄로 전체 EKS 인프라 및 마이크로서비스 배포, DB 초기화, E2E 테스트까지 자동 수행됩니다:

```powershell
.\run-all.ps1
```

### 🌐 모니터링 UI 포트
* **API Gateway**: `http://localhost:8080`
* **Grafana 대시보드**: `http://localhost:3000` (`admin` / `admin`)
* **Jaeger 트레이싱**: `http://localhost:16686`
* **Prometheus**: `http://localhost:9090`
* **Consul UI**: `http://localhost:8500`
