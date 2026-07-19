# Big Data Platform Microservices 실행 가이드 v2

본 가이드는 Windows (PowerShell) 환경에서 **Big Data Platform 마이크로서비스 프로젝트**를 순차적으로 빌드, 배포, 테스트하는 최신 2.0 버전 지침서입니다.

---

## 1. 프로젝트 아키텍처 개요

본 플랫폼은 5개의 Java Spring Boot 마이크로서비스와 분산 인프라로 구성됩니다:

* **API Gateway (`port 8080`)**: 서비스 라우팅 및 단일 진입점
* **User Service (`port 8081`)**: 회원 관리 (PostgreSQL + Redis Caching)
* **Product Service (`port 8083`)**: 상품 관리 (Apache Cassandra)
* **Order Service (`port 8082`)**: 주문 처리 (PostgreSQL + Kafka Event Publishing)
* **Notification Service (`port 8084`)**: 알림 처리 (Kafka Consumer + Redis)
* **인프라**: Consul (Service Discovery), PostgreSQL, Cassandra, Redis, ZooKeeper, Kafka, LocalStack (AWS EKS/S3/RDS/Redis 시뮬레이션), Prometheus, Grafana, Jaeger

---

## 2. 사전 요구사항 (Prerequisites)

호스트에 Java나 Maven을 직접 설치하지 않아도 **Docker Container**를 통해 빌드할 수 있습니다.

### 필수 소프트웨어
* **Docker Desktop**: 최신 버전 (WSL2 백엔드 사용 권장)
* **Python**: 3.8 이상 (E2E 테스트 스크립트 실행용)
* **AWS CLI**: v2.0 이상 (LocalStack EKS 연동용)
* **Terraform**: v1.0 이상 (LocalStack AWS 인프라 프로비저닝용)
* **kubectl**: Kubernetes 클러스터 제어용

---

## 3. 방법 A: Docker & Docker Compose로 빠르게 실행하기 (권장 개발 모드)

로컬 개발 및 API 기능 테스트에 가장 빠르고 간편한 방법입니다.

### Step 1. 인프라 컨테이너 실행
프로젝트 루트 디렉토리(`c:/pj/bigdataplatform`)에서 미들웨어 인프라를 백그라운드로 실행합니다.

```powershell
# 프로젝트 루트 이동
cd c:/pj/bigdataplatform

# 인프라 컴포넌트 전체 구동
docker-compose up -d consul postgres cassandra redis zookeeper kafka elasticsearch prometheus grafana jaeger localstack
```

### Step 2. 데이터베이스 및 메시지 브로커 초기화
PostgreSQL 테이블, Cassandra 스키마, Kafka 토픽을 각각 생성합니다.

```powershell
# 1) Cassandra 테이블 스키마 생성
Get-Content scripts/setup-cassandra.cql | docker exec -i cassandra cqlsh

# 2) PostgreSQL 마이크로서비스 DB 스키마 생성
Get-Content scripts/setup-database.sql | docker exec -i postgres psql -U admin -d microservices

# 3) Kafka 'orders' 토픽 생성
docker exec kafka kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --topic orders
```

### Step 3. Docker 기반 Maven 마이크로서비스 JAR 빌드
호스트 JDK/Maven 없이 도커 Maven 컨테이너를 사용하여 5개 서비스를 컴파일 및 패키징합니다.

```powershell
# Maven Docker 컨테이너로 5개 마이크로서비스 일괄 빌드
docker run --rm -v c:/pj/bigdataplatform:/app -v c:/Users/$env:USERNAME/.m2:/root/.m2 -w /app maven:3.9-eclipse-temurin-17-alpine sh -c "
  cd services/api-gateway && mvn clean package -DskipTests && cd ../.. &&
  cd services/user-service && mvn clean package -DskipTests && cd ../.. &&
  cd services/product-service && mvn clean package -DskipTests && cd ../.. &&
  cd services/order-service && mvn clean package -DskipTests && cd ../.. &&
  cd services/notification-service && mvn clean package -DskipTests
"
```

### Step 4. 도커 이미지 빌드 및 마이크로서비스 컨테이너 구동

```powershell
# 1) Docker 이미지 빌드
docker build -t api-gateway:latest services/api-gateway
docker build -t user-service:latest services/user-service
docker build -t product-service:latest services/product-service
docker build -t order-service:latest services/order-service
docker build -t notification-service:latest services/notification-service

# 2) 마이크로서비스 컨테이너 실행 (동일 네트워크 연결)
docker run -d --name api-gateway --network bigdataplatform_microservices-network -p 8080:8080 api-gateway:latest
docker run -d --name user-service --network bigdataplatform_microservices-network -p 8081:8081 user-service:latest
docker run -d --name product-service --network bigdataplatform_microservices-network -p 8083:8083 product-service:latest
docker run -d --name order-service --network bigdataplatform_microservices-network -p 8082:8082 order-service:latest
docker run -d --name notification-service --network bigdataplatform_microservices-network -p 8084:8084 notification-service:latest
```

### Step 5. API Gateway 시나리오 테스트 실행
작성된 통합 테스트 스크립트([scripts/test-api.py](file:///c:/pj/bigdataplatform/scripts/test-api.py))를 실행하여 유저 생성, 조회, 상품 등록, 상품 목록 조회, 주문 생성, 주문 조회가 정상 작동하는지 검증합니다.

```powershell
python scripts/test-api.py
```
> **[SUCCESS] All API Gateway End-to-End Tests Passed Successfully!** 메시지가 출력되면 정상 완료된 것입니다.

---

## 4. 방법 B: LocalStack AWS EKS & Kubernetes 환경 배포 (배포 모드)

LocalStack 상에 AWS EKS 클러스터를 생성하고 Kubernetes 매니페스트(`k8s/`)를 배포하는 프로세스입니다.

### Step 1. LocalStack 환경 설정 검증
`docker-compose.yml`의 `localstack` 서비스에 호스트 도커 소켓이 마운트되어 있는지 확인합니다:
* `/var/run/docker.sock:/var/run/docker.sock`

### Step 2. Terraform으로 AWS 리소스 생성
LocalStack 상에 S3, RDS Postgres, ElastiCache Redis, IAM Role을 프로비저닝합니다.

```powershell
cd terraform-aws
terraform init
terraform apply -auto-approve
cd ..
```

### Step 3. LocalStack EKS 클러스터 생성 및 kubectl 연동

```powershell
# 1) LocalStack 서브넷 및 보안그룹 ID 조회
$SubnetId = (aws ec2 describe-subnets --endpoint-url http://localhost:4566 --region ap-northeast-2 --query "Subnets[0].SubnetId" --output text)
$SgId = (aws ec2 describe-security-groups --endpoint-url http://localhost:4566 --region ap-northeast-2 --query "SecurityGroups[0].GroupId" --output text)

# 2) EKS 클러스터 생성 요청
aws eks create-cluster --name bigdataplatform-eks `
  --role-arn arn:aws:iam::000000000000:role/bigdataplatform-kubernetes-role `
  --resources-vpc-config subnetIds=$SubnetId,securityGroupIds=$SgId `
  --endpoint-url http://localhost:4566 --region ap-northeast-2

# 3) 클러스터 ACTIVE 상태 대기 (약 30~40초 소요)
aws eks describe-cluster --name bigdataplatform-eks --endpoint-url http://localhost:4566 --region ap-northeast-2 --query cluster.status

# 4) kubectl 설정 업데이트
aws eks update-kubeconfig --name bigdataplatform-eks --endpoint-url http://localhost:4566 --region ap-northeast-2

# 5) 클러스터 노드 확인
kubectl get nodes
```

### Step 4. 빌드된 Docker 이미지를 EKS 클러스터(k3d)에 임포트

```powershell
# LocalStack 내부의 k3d 엔진을 호출하여 로컬 도커 이미지를 k8s 노드로 주입
$ClusterNode = (docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 cluster list --no-headers | ForEach-Object { $_.Split()[0] })

docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 image import `
  api-gateway:latest user-service:latest product-service:latest order-service:latest notification-service:latest `
  -c $ClusterNode
```

### Step 5. Kubernetes 매니페스트 배포

```powershell
# k8s 리소스 일괄 배포 및 초기화
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-pvc.yaml
kubectl apply -f k8s/04-statefulset.yaml
kubectl apply -f k8s/05-deployment.yaml
kubectl apply -f k8s/06-service.yaml
```

### Step 6. Pod 상태 및 서비스 포트 포워딩
Pod들이 정상 실행(`Running`, `2/2` 또는 `1/1`) 상태인지 확인합니다.

```powershell
# Pod 상태 조회
kubectl get pods -n bigdataplatform

# API Gateway 포트 포워딩 (외부 테스트용)
kubectl port-forward -n bigdataplatform service/api-gateway 8080:8080
```

---

## 5. 트러블슈팅 및 패치 내역 (Reference)

이 프로젝트를 구동할 때 해결된 주요 핵심 설정 사항들입니다:

1. **Spring Boot 3.x Redis 및 Cassandra 네임스페이스 키 변경**
   * Redis: `spring.redis` 대신 `spring.data.redis` 사용.
   * Cassandra: `spring.data.cassandra` 대신 `spring.cassandra` 사용 (`contact-points` 리스트 형태 지정).
2. **Order 엔티티 JSON 역직렬화 NPE 방지**
   * `Order.java` 파일에서 `status = "PENDING"`, `createdAt`, `updatedAt` 필드를 기본값으로 초기화하여 HTTP POST 요청 시 DB 제약조건 위반(500 에러)을 방지함.
3. **LocalStack S3 DNS 도메인 에러 방지**
   * `terraform-aws/main.tf`의 AWS Provider에 `s3_use_path_style = true`를 추가하여 `*.localhost` DNS 조회가 안되는 환경에서도 정상 접근 가능하도록 처리함.
4. **Windows 인코딩 대응**
   * Python 스크립트(`scripts/test-api.py`) 및 콘솔 출력 시 Windows 한글 CP949 코드페이지 호환을 위해 특수 유니코드 문자(✓, ❌) 대신 ASCII 키워드(`[OK]`, `[FAIL]`)를 사용함.
