# 실행 가이드

이 가이드는 마이크로서비스 기반 분산 시스템을 처음부터 끝까지 실행하는 단계별 지침입니다.

## 목차

1. [사전 요구사항](#사전-요구사항)
2. [인프라 시작](#인프라-시작)
3. [데이터베이스 설정](#데이터베이스-설정)
4. [샘플 데이터 생성](#샘플-데이터-생성)
5. [마이크로서비스 빌드 및 실행](#마이크로서비스-빌드-및-실행)
6. [LocalStack 및 Terraform 배포](#localstack-및-terraform-배포)
7. [테스트 및 검증](#테스트-및-검증)
8. [정리](#정리)

---

## 사전 요구사항

### 필수 소프트웨어

- **Docker**: 20.10 이상
- **Docker Compose**: 2.0 이상
- **Python**: 3.8 이상 (샘플 데이터 생성용)
- **Terraform**: 1.0 이상 (LocalStack 배포용)
- **Java**: 17 이상 (마이크로서비스 실행용)
- **Maven**: 3.8 이상 (마이크로서비스 빌드용)

### 설치 확인

```bash
# Docker 설치 확인
docker --version
docker-compose --version

# Python 설치 확인
python --version

# Terraform 설치 확인
terraform --version

# Java 설치 확인
java -version

# Maven 설치 확인
mvn -version
```

### Python 의존성 설치

```bash
# 샘플 데이터 생성용 패키지
pip install psycopg2-binary
```

---

## 인프라 시작

### 1. Docker Compose로 인프라 컴포넌트 시작

```bash
# 프로젝트 루트 디렉토리로 이동
cd c:/pj/bigdataplatform

# 모든 인프라 컴포넌트 시작
docker-compose up -d

# 또는 특정 서비스만 시작
docker-compose up -d consul postgres cassandra redis zookeeper kafka elasticsearch prometheus grafana jaeger localstack
```

### 2. 컨테이너 상태 확인

```bash
# 모든 컨테이너 상태 확인
docker-compose ps

# 특정 컨테이너 로그 확인
docker-compose logs postgres
docker-compose logs cassandra
docker-compose logs localstack
```

### 3. 서비스 접속 테스트

```bash
# Consul UI 접속
# http://localhost:8500

# Prometheus UI 접속
# http://localhost:9090

# Grafana UI 접속
# http://localhost:3000 (admin/admin)

# Jaeger UI 접속
# http://localhost:16686

# LocalStack 대시보드 접속
# http://localhost:4566/_dashboard
```

---

## 데이터베이스 설정

### 1. PostgreSQL 데이터베이스 설정

```bash
# 기본 데이터베이스 스키마 생성
docker exec -i postgres psql -U admin -d microservices < scripts/setup-database.sql

# 복잡한 데이터 모델 적용 (쿼리 튜닝용)
docker exec -i postgres psql -U admin -d microservices < scripts/complex-database.sql
```

### 2. Cassandra Keyspace 설정

```bash
# Cassandra가 완전히 시작될 때까지 대기 (약 30-60초)
docker exec cassandra cqlsh -e "DESCRIBE KEYSPACES;"

# Keyspace 및 테이블 생성
docker exec -i cassandra cqlsh < scripts/setup-cassandra.cql
```

### 3. Kafka 토픽 생성

```bash
# Kafka가 완전히 시작될 때까지 대기
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 주문 토픽 생성
docker exec kafka kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --topic orders

# 토픽 확인
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

---

## 샘플 데이터 생성

### 1. 샘플 데이터 생성 스크립트 실행

```bash
# Python 스크립트로 대용량 샘플 데이터 생성
python scripts/generate-sample-data.py
```

### 2. 데이터 생성 확인

```bash
# PostgreSQL 데이터 확인
docker exec -i postgres psql -U admin -d microservices -c "SELECT COUNT(*) FROM users;"
docker exec -i postgres psql -U admin -d microservices -c "SELECT COUNT(*) FROM products;"
docker exec -i postgres psql -U admin -d microservices -c "SELECT COUNT(*) FROM orders;"

# Cassandra 데이터 확인
docker exec cassandra cqlsh -e "SELECT COUNT(*) FROM products.products;"
```

---

## 마이크로서비스 빌드 및 실행

### 1. 마이크로서비스 빌드

```bash
# API Gateway 빌드
cd services/api-gateway
mvn clean package -DskipTests
cd ../..

# User Service 빌드
cd services/user-service
mvn clean package -DskipTests
cd ../..

# Order Service 빌드
cd services/order-service
mvn clean package -DskipTests
cd ../..

# Product Service 빌드
cd services/product-service
mvn clean package -DskipTests
cd ../..

# Notification Service 빌드
cd services/notification-service
mvn clean package -DskipTests
cd ../..
```

### 2. 마이크로서비스 실행

```bash
# API Gateway 실행
cd services/api-gateway
mvn spring-boot:run &
cd ../..

# User Service 실행
cd services/user-service
mvn spring-boot:run &
cd ../..

# Order Service 실행
cd services/order-service
mvn spring-boot:run &
cd ../..

# Product Service 실행
cd services/product-service
mvn spring-boot:run &
cd ../..

# Notification Service 실행
cd services/notification-service
mvn spring-boot:run &
cd ../..
```

### 3. 또는 자동 배포 스크립트 사용

```bash
# 전체 자동 배포 스크립트 실행
bash scripts/deploy.sh
```

### 4. 서비스 상태 확인

```bash
# API Gateway 테스트
curl http://localhost:8080/actuator/health

# User Service 테스트
curl http://localhost:8081/actuator/health

# Order Service 테스트
curl http://localhost:8082/actuator/health

# Product Service 테스트
curl http://localhost:8083/actuator/health

# Notification Service 테스트
curl http://localhost:8084/actuator/health
```

---

## LocalStack 및 Terraform 배포

### 1. LocalStack 시작

```bash
# LocalStack이 이미 실행 중인지 확인
docker ps | grep localstack

# 실행 중이지 않다면 시작
docker-compose up -d localstack

# LocalStack 대시보드 접속
# http://localhost:4566/_dashboard
```

### 2. Terraform 초기화

```bash
# Terraform 디렉토리로 이동
cd terraform

# Terraform 초기화
terraform init

# 테라폼 버전 확인
terraform version
```

### 3. 실행 계획 확인

```bash
# 실행 계획 생성
terraform plan

# 또는 스크립트 사용
cd ..
bash scripts/terraform-plan.sh
cd terraform
```

### 4. 리소스 배포

```bash
# 리소스 배포
terraform apply

# 또는 스크립트 사용
cd ..
bash scripts/terraform-deploy.sh
cd terraform
```

### 5. 배포된 리소스 확인

```bash
# 배포된 리소스 상태 확인
terraform show

# 출력 값 확인
terraform output

# 특정 리소스 정보 확인
terraform output alb_dns_name
terraform output rds_endpoint
terraform output redis_endpoint
```

---

## 테스트 및 검증

### 1. API 테스트

```bash
# 사용자 생성
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# 사용자 조회
curl http://localhost:8080/api/users/1

# 상품 생성
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Product","description":"Test Description","price":99.99,"stock":100,"category":"Electronics"}'

# 상품 조회
curl http://localhost:8080/api/products

# 주문 생성
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId":1,"productId":1,"quantity":2,"totalAmount":199.98}'

# 주문 조회
curl http://localhost:8080/api/orders/1
```

### 2. 복잡한 쿼리 테스트

```bash
# 복잡한 쿼리 실행
docker exec -i postgres psql -U admin -d microservices < scripts/complex-queries.sql
```

### 3. 인덱스 최적화 테스트

```bash
# 인덱스 최적화 스크립트 실행
docker exec -i postgres psql -U admin -d microservices < scripts/index-optimization.sql
```

### 4. 쿼리 성능 분석

```bash
# 쿼리 성능 분석 도구 설정
docker exec -i postgres psql -U admin -d microservices < scripts/query-performance-analysis.sql
```

### 5. 모니터링 대시보드 확인

- **Consul**: http://localhost:8500 (서비스 디스커버리)
- **Prometheus**: http://localhost:9090 (메트릭 수집)
- **Grafana**: http://localhost:3000 (시각화, admin/admin)
- **Jaeger**: http://localhost:16686 (분산 트레이싱)
- **LocalStack**: http://localhost:4566/_dashboard (AWS 리소스)

---

## 정리

### 1. 마이크로서비스 중지

```bash
# 실행 중인 마이크로서비스 프로세스 중지
pkill -f "spring-boot:run"
```

### 2. Terraform 리소스 삭제

```bash
cd terraform

# 리소스 삭제
terraform destroy

# 또는 스크립트 사용
cd ..
bash scripts/terraform-destroy.sh
cd terraform
```

### 3. Docker 컨테이너 중지

```bash
# 모든 컨테이너 중지
docker-compose down

# 볼륨까지 삭제
docker-compose down -v
```

### 4. 로그 및 데이터 정리

```bash
# LocalStack 데이터 삭제
rm -rf localstack_data

# 테라폼 상태 파일 삭제
cd terraform
rm -rf .terraform terraform.tfstate terraform.tfstate.backup
cd ..
```

---

## 빠른 시작 (요약)

### 전체 자동 실행

```bash
# 1. 인프라 시작
docker-compose up -d

# 2. 데이터베이스 설정
docker exec -i postgres psql -U admin -d microservices < scripts/setup-database.sql
docker exec -i cassandra cqlsh < scripts/setup-cassandra.cql
docker exec kafka kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --topic orders

# 3. 샘플 데이터 생성
python scripts/generate-sample-data.py

# 4. 마이크로서비스 배포
bash scripts/deploy.sh

# 5. LocalStack 배포
docker-compose up -d localstack
cd terraform
terraform init
terraform apply
```

---

## 문제 해결

### 인프라 시작 실패

```bash
# Docker 데몬 상태 확인
docker ps

# 컨테이너 로그 확인
docker-compose logs [service-name]

# 컨테이너 재시작
docker-compose restart [service-name]
```

### 데이터베이스 연결 실패

```bash
# PostgreSQL 컨테이너 상태 확인
docker-compose ps postgres

# Cassandra 컨테이너 상태 확인
docker-compose ps cassandra

# 네트워크 연결 테스트
docker exec postgres ping postgres
docker exec cassandra ping cassandra
```

### 마이크로서비스 시작 실패

```bash
# 포트 충돌 확인
netstat -ano | findstr :8080
netstat -ano | findstr :8081

# 로그 확인
cd services/[service-name]
mvn spring-boot:run
```

### Terraform 실행 실패

```bash
# LocalStack 연결 확인
curl http://localhost:4566

# 테라폼 상태 확인
terraform state list

# 테라폼 캐시 삭제
rm -rf .terraform
terraform init
```

---

## 추가 리소스

- **메인 README**: [README.md](README.md)
- **서비스 문서**: 각 서비스 디렉토리의 README.md
- **API 문서**: 각 서비스의 Swagger UI (http://localhost:[port]/swagger-ui.html)
- **모니터링**: Grafana 대시보드
- **분산 트레이싱**: Jaeger UI

---

## 지원

문제가 발생하면 다음을 확인하세요:
1. Docker 및 Docker Compose 버전
2. 포트 충돌 여부
3. 컨테이너 로그
4. 서비스 상태
5. 네트워크 연결
