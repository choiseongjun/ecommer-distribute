# AWS EKS 배포 가이드

이 가이드는 실제 AWS 환경에 마이크로서비스 플랫폼을 배포하는 방법을 설명합니다.

## 사전 요구사항

### 필수 도구
- **AWS Account**: 활성 AWS 계정
- **AWS CLI**: v2.0 이상
- **Terraform**: v1.0 이상
- **kubectl**: EKS 버전과 호환
- **Docker**: 이미지 빌드용
- **Maven**: 마이크로서비스 빌드용

### AWS IAM 권한
다음 IAM 권한이 필요합니다:
- EC2 Full Access
- EKS Full Access
- VPC Full Access
- RDS Full Access
- ElastiCache Full Access
- S3 Full Access
- IAM Full Access
- CloudWatch Full Access

## 배포 단계

### 1. AWS CLI 설정

```bash
# AWS CLI 설치 확인
aws --version

# AWS 계정 설정
aws configure
# AWS Access Key ID: [입력]
# AWS Secret Access Key: [입력]
# Default region name: ap-northeast-2
# Default output format: json
```

### 2. Terraform 백엔드 설정

Terraform 상태를 저장할 S3 버킷과 DynamoDB 테이블을 생성합니다:

```bash
# S3 버킷 생성
aws s3 mb s3://bigdataplatform-terraform-state --region ap-northeast-2

# 버전 관리 활성화
aws s3api put-bucket-versioning --bucket bigdataplatform-terraform-state --versioning-configuration Status=Enabled

# DynamoDB 테이블 생성 (상태 잠금용)
aws dynamodb create-table \
  --table-name bigdataplatform-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-2
```

### 3. EKS 클러스터 배포

```powershell
# EKS 배포 스크립트 실행
.\scripts\aws-eks-deploy.ps1
```

또는 수동으로:

```bash
cd terraform-aws
terraform init
terraform plan
terraform apply
```

### 4. kubeconfig 업데이트

```bash
aws eks update-kubeconfig --name bigdataplatform-eks --region ap-northeast-2

# 클러스터 연결 확인
kubectl cluster-info
kubectl get nodes
```

### 5. ECR 이미지 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 및 푸시
cd services/api-gateway
mvn clean package -DskipTests
docker build -t api-gateway:latest .
docker tag api-gateway:latest <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/bigdataplatform/api-gateway:latest
docker push <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/bigdataplatform/api-gateway:latest

# 다른 서비스도 동일하게 반복
```

### 6. Kubernetes 리소스 배포

ECR 이미지 URL로 k8s 매니페스트를 수정한 후 배포:

```bash
# 네임스페이스 및 설정 배포
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmap.yaml
kubectl apply -f k8s/02-secret.yaml

# StatefulSet 배포 (데이터베이스는 AWS RDS/ElastiCache 사용하므로 생략 가능)
kubectl apply -f k8s/04-statefulset.yaml

# Deployment 배포 (이미지 URL을 ECR로 수정)
kubectl apply -f k8s-aws/05-deployment.yaml

# Service 배포
kubectl apply -f k8s-aws/06-service.yaml
```

### 7. 데이터베이스 초기화

```bash
# RDS PostgreSQL 초기화
kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices < scripts/setup-database.sql
kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices < scripts/complex-database.sql

# Cassandra 초기화 (Kubernetes StatefulSet 사용 시)
kubectl exec -n bigdataplatform cassandra-0 -- cqlsh < scripts/setup-cassandra.cql
```

### 8. ALB 접속

```bash
# ALB DNS 이름 확인
terraform output alb_dns_name

# 또는
kubectl get svc -n bigdataplatform
```

## 비용 최적화

### 개발 환경
- **EKS**: t3.medium 노드 2개
- **RDS**: db.t3.micro
- **ElastiCache**: cache.t3.micro
- **S3**: Standard Tier

### 프로덕션 환경
- **EKS**: m5.large 노드 3개 이상
- **RDS**: db.r5.large (Multi-AZ)
- **ElastiCache**: cache.r5.large (Multi-AZ)
- **S3**: Intelligent Tiering

## 보안 설정

### 1. VPC 보안
- 프라이빗 서브넷에 데이터베이스 배치
- 보안 그룹으로 접근 제한
- VPC Endpoint 사용

### 2. 데이터 암호화
- RDS 스토리지 암호화
- EBS 볼륨 암호화
- S3 버킷 암호화
- KMS 키 관리

### 3. IAM 역할
- 최소 권한 원칙 적용
- 서비스별 IAM 역할 분리
- IAM 정책 정기 검토

안

## 모니터링

### CloudWatch
- EKS 클러스터 메트릭
- RDS 성능 메트릭
- ElastiCache 메트릭
- ALB 액세스 로그

### Prometheus & Grafana
- Kubernetes 메트릭 수집
- 애플리케이션 메트릭
- 대시보드 구성

## 트러블슈팅

### EKS 클러스터 연결 실패
```bash
# kubeconfig 재설정
aws eks update-kubeconfig --name bigdataplatform-eks --region ap-northeast-2 --force

# IAM 권한 확인
aws iam get-user
```

### ECR 푸시 실패
```bash
# ECR 로그인 재시도
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# IAM 권한 확인
aws iam list-attached-user-policies --user-name <username>
```

### Pod 시작 실패
```bash
# Pod 상태 확인
kubectl describe pod <pod-name> -n bigdataplatform

# 이벤트 확인
kubectl get events -n bigdataplatform

# 로그 확인
kubectl logs <pod-name> -n bigdataplatform
```

## 비용 추정

### 월 예상 비용 (개발 환경)
- **EKS**: $73/월 (t3.medium 2개)
- **RDS**: $15/월 (db.t3.micro)
- **ElastiCache**: $25/월 (cache.t3.micro)
- **ALB**: $18/월
- **S3**: $2/월
- **CloudWatch**: $10/월
- **총계**: 약 $143/월

### 비용 절감 팁
- 개발 환경은 사용 시에만 실행
- Spot Instance 사용
- S3 수명 주기 정책 설정
- CloudWatch Logs 보관 기간 단축

## 정리

```bash
# Kubernetes 리소스 삭제
kubectl delete namespace bigdataplatform

# Terraform 리소스 삭제
cd terraform-aws
terraform destroy

# S3 버킷 삭제
aws s3 rb s3://bigdataplatform-terraform-state --force

# DynamoDB 테이블 삭제
aws dynamodb delete-table --table-name bigdataplatform-terraform-locks
```

## 다음 단계

1. **CI/CD 파이프라인**: GitHub Actions 또는 AWS CodePipeline
2. **GitOps**: ArgoCD 또는 Flux
3. **서비스 메시**: Istio 또는 AWS App Mesh
4. **Auto Scaling**: HPA 및 Cluster Autoscaler
5. **멀티 리전 배포**: Cross-region 복제
