# LocalStack EKS 배포 가이드

이 가이드는 LocalStack에서 EKS 클러스터를 시뮬레이션하고 AWS 서비스를 테스트하는 방법을 설명합니다.

## 개요

LocalStack은 로컬 환경에서 AWS 서비스를 시뮬레이션하는 도구입니다. 이 가이드에서는 LocalStack을 사용하여 EKS, RDS, ElastiCache, S3 등의 AWS 서비스를 로컬에서 테스트합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    LocalStack (AWS Simulation)              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  AWS Services (시뮬레이션)                            │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐              │  │
│  │  │   S3     │ │   RDS    │ │ ElastiCache│             │  │
│  │  └──────────┘ └──────────┘ └──────────┘              │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐              │  │
│  │  │   IAM    │ │   EKS    │ │  Lambda  │              │  │
│  │  └──────────┘ └──────────┘ └──────────┘              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │
         │ Terraform
         ▼
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes (로컬 클러스터)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Microservices                                        │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐              │  │
│  │  │API Gateway│ │User Service│ │Order Service│         │  │
│  │  └──────────┘ └──────────┘ └──────────┘              │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 사전 요구사항

### 필수 도구
- **Docker**: 20.10 이상
- **Docker Compose**: 2.0 이상
- **Terraform**: v1.0 이상
- **AWS CLI**: v2.0 이상
- **kubectl**: v1.24 이상

### LocalStack API Key
- 제공된 API Key: `ls-caWEzuMo-0827-dIMI-FAke-CeTU39677256`

## 배포 단계

### 1. LocalStack 시작

```powershell
# LocalStack 시작
docker-compose up -d localstack

# 상태 확인
docker ps | findstr localstack

# 로그 확인
docker logs localstack -f
```

### 2. LocalStack 연결 확인

```powershell
# LocalStack 헬스 체크
curl http://localhost:4566/_localstack/health

# 또는 PowerShell
Invoke-WebRequest -Uri "http://localhost:4566/_localstack/health"
```

### 3. AWS CLI LocalStack 설정

```powershell
# AWS CLI LocalStack 설정
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set default.region ap-northeast-2
aws configure set default.output json

# 환경 변수 설정
$Env:AWS_ENDPOINT_URL = "http://localhost:4566"
```

### 4. Terraform으로 AWS 리소스 배포

```powershell
# LocalStack 배포 스크립트 실행
.\scripts\localstack-eks-deploy.ps1
```

또는 수동으로:

```bash
cd terraform-aws
terraform init
terraform plan
terraform apply
```

### 5. 배포된 리소스 확인

```powershell
# S3 버킷 확인
aws s3 ls --endpoint-url http://localhost:4566

# RDS 인스턴스 확인
aws rds describe-db-instances --endpoint-url http://localhost:4566

# ElastiCache 확인
aws elasticache describe-replication-groups --endpoint-url http://localhost:4566

# IAM 역할 확인
aws iam list-roles --endpoint-url http://localhost:4566
```

### 6. Kubernetes 리소스 배포

LocalStack에서는 실제 EKS 클러스터 대신 로컬 Kubernetes 클러스터를 사용합니다:

```powershell
# Kubernetes 리소스 배포
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-pvc.yaml
kubectl apply -f k8s/04-statefulset.yaml
kubectl apply -f k8s/05-deployment.yaml
kubectl apply -f k8s/06-service.yaml
```

### 7. LocalStack 대시보드 접속

LocalStack 웹 UI는 현재 버전에서 다를 수 있습니다. 대신 AWS CLI를 사용하여 리소스를 확인하세요:

```powershell
# S3 버킷 목록
aws s3 ls --endpoint-url http://localhost:4566

# RDS 인스턴스 목록
aws rds describe-db-instances --endpoint-url http://localhost:4566

# ElastiCache 목록
aws elasticache describe-replication-groups --endpoint-url http://localhost:4566

# IAM 역할 목록
aws iam list-roles --endpoint-url http://localhost:4566
```

또는 브라우저에서 다음 URL로 접속해보세요:
- http://localhost:4566 (기본 API 엔드포인트)

## Terraform 리소스

LocalStack용 Terraform 설정은 다음 AWS 리소스를 배포합니다:

### S3 Buckets
- **bigdataplatform-assets**: 정적 파일 저장
- **bigdataplatform-logs**: 로그 파일 저장

### RDS PostgreSQL
- **bigdataplatform-postgres**: PostgreSQL 데이터베이스
  - Engine: PostgreSQL 15.4
  - Instance: db.t3.micro
  - Storage: 20GB

### ElastiCache Redis
- **bigdataplatform-redis**: Redis 캐시
  - Engine: Redis 7.0
  - Node Type: cache.t3.micro

### IAM Role
- **bigdataplatform-kubernetes-role**: Kubernetes용 IAM 역할
  - S3 Full Access
  - RDS Full Access

## LocalStack 서비스

LocalStack에서 시뮬레이션되는 AWS 서비스:
- **EKS**: Kubernetes 클러스터 (제한적 지원)
- **RDS**: 관계형 데이터베이스
- **ElastiCache**: Redis 캐시
- **S3**: 오브젝트 스토리지
- **IAM**: 역할 및 정책 관리
- **Lambda**: 서버리스 함수
- **API Gateway**: API 게이트웨이
- **DynamoDB**: NoSQL 데이터베이스
- **SQS/SNS**: 메시징 서비스
- **CloudFormation**: 인프라 코드화

## 트러블슈팅

### LocalStack 시작 실패

```powershell
# 컨테이너 상태 확인
docker ps | findstr localstack

# 컨테이너 로그 확인
docker logs localstack

# 컨테이너 재시작
docker-compose restart localstack

# 컨테이너 재생성
docker-compose down localstack
docker-compose up -d localstack
```

### Terraform 실행 실패

```powershell
# LocalStack 연결 확인
curl http://localhost:4566/_localstack/health

# Terraform 상태 확인
cd terraform-aws
terraform state list

# Terraform 캐시 삭제
rm -rf .terraform
terraform init
```

### AWS CLI 연결 실패

```powershell
# AWS CLI 설정 확인
aws configure list

# 엔드포인트 설정 확인
$Env:AWS_ENDPOINT_URL

# 테스트 명령어
aws s3 ls --endpoint-url http://localhost:4566
```

### 포트 충돌

```powershell
# 포트 사용 확인
netstat -ano | findstr 4566

# 다른 포트 사용 (docker-compose.yml 수정)
ports:
  - "4567:4566"  # 4566 대신 4567 사용
```

## LocalStack 제한사항

### EKS 제한
- LocalStack의 EKS는 완전한 기능을 제공하지 않습니다
- 실제 EKS 클러스터 대신 시뮬레이션된 환경
- 일부 EKS 기능은 지원되지 않을 수 있습니다

### 서비스 제한
- 일부 AWS 서비스는 부분적으로만 지원
- 복잡한 구성은 제한될 수 있음
- 성능은 실제 AWS와 다를 수 있음

## 비용

LocalStack은 로컬 환경에서 실행되므로 AWS 비용이 발생하지 않습니다.

## 정리

```powershell
# Kubernetes 리소스 삭제
kubectl delete namespace bigdataplatform

# Terraform 리소스 삭제
cd terraform-aws
terraform destroy

# LocalStack 중지
docker-compose down localstack

# LocalStack 데이터 삭제
rm -rf localstack_data
```

## 다음 단계

1. **실제 AWS 배포**: AWS_EKS_GUIDE.md 참조
2. **CI/CD 통합**: GitHub Actions 또는 GitLab CI
3. **모니터링**: Prometheus & Grafana 구성
4. **테스트**: 통합 테스트 및 E2E 테스트

## 참고 자료

- [LocalStack 문서](https://docs.localstack.cloud/)
- [Terraform LocalStack Provider](https://registry.terraform.io/providers/localstack/localstack/latest/docs)
- [AWS CLI 설치](https://aws.amazon.com/cli/)
