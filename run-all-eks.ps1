# PowerShell Master Automation Script for LocalStack AWS EKS Deployment
# LocalStack AWS 리소스 프로비저닝, EKS 클러스터 생성, Docker 이미지 임포트 및 Kubernetes 리소스 배포 자동화

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor White
}

# 0. 시스템 PATH 갱신
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

Write-Header "LocalStack AWS EKS 전체 자동 배포 시작"

# 1. LocalStack 인프라 시작
Write-Header "Step 1/7: LocalStack 및 필수 인프라 시작 중..."
docker-compose up -d localstack postgres cassandra redis zookeeper kafka
Write-Success "LocalStack 인프라 구동 완료"

# 2. Terraform 배포
Write-Header "Step 2/7: Terraform으로 LocalStack AWS 리소스 (S3, RDS, Redis, IAM) 배포 중..."
Set-Location "$ProjectRoot\terraform-aws"
terraform init
terraform apply -auto-approve
Set-Location $ProjectRoot
Write-Success "Terraform 리소스 생성 완료"

# 3. EKS 클러스터 생성
Write-Header "Step 3/7: LocalStack EKS 클러스터 생성 중..."
$SubnetId = (aws ec2 describe-subnets --endpoint-url http://localhost:4566 --region ap-northeast-2 --query "Subnets[0].SubnetId" --output text)
$SgId = (aws ec2 describe-security-groups --endpoint-url http://localhost:4566 --region ap-northeast-2 --query "SecurityGroups[0].GroupId" --output text)

Write-Info "서브넷: $SubnetId, 보안그룹: $SgId"
aws eks create-cluster --name bigdataplatform-eks `
  --role-arn arn:aws:iam::000000000000:role/bigdataplatform-kubernetes-role `
  --resources-vpc-config subnetIds=$SubnetId,securityGroupIds=$SgId `
  --endpoint-url http://localhost:4566 --region ap-northeast-2

Write-Info "EKS 클러스터 활성화(ACTIVE) 대기 중..."
while ($true) {
    $Status = (aws eks describe-cluster --name bigdataplatform-eks --endpoint-url http://localhost:4566 --region ap-northeast-2 --query cluster.status --output text)
    Write-Info "현재 EKS 상태: $Status"
    if ($Status -eq "ACTIVE") { break }
    Start-Sleep -Seconds 10
}
Write-Success "LocalStack EKS 클러스터 활성화 완료"

# 4. Kubeconfig 설정
Write-Header "Step 4/7: kubeconfig 업데이트 및 노드 연결 확인..."
aws eks update-kubeconfig --name bigdataplatform-eks --endpoint-url http://localhost:4566 --region ap-northeast-2
kubectl get nodes
Write-Success "EKS 클러스터 연결 확인 완료"

# 5. Docker 마이크로서비스 빌드
Write-Header "Step 5/7: 마이크로서비스 JAR 빌드 및 Docker 이미지 생성 중..."
docker run --rm -v "${ProjectRoot}:/app" -v "c:/Users/$env:USERNAME/.m2:/root/.m2" -w /app maven:3.9-eclipse-temurin-17-alpine sh -c "
  cd services/api-gateway && mvn clean package -DskipTests && cd ../.. &&
  cd services/user-service && mvn clean package -DskipTests && cd ../.. &&
  cd services/product-service && mvn clean package -DskipTests && cd ../.. &&
  cd services/order-service && mvn clean package -DskipTests && cd ../.. &&
  cd services/notification-service && mvn clean package -DskipTests
"

docker build -t api-gateway:latest "$ProjectRoot\services\api-gateway"
docker build -t user-service:latest "$ProjectRoot\services\user-service"
docker build -t product-service:latest "$ProjectRoot\services\product-service"
docker build -t order-service:latest "$ProjectRoot\services\order-service"
docker build -t notification-service:latest "$ProjectRoot\services\notification-service"
Write-Success "Docker 이미지 빌드 완료"

# 6. EKS 클러스터 (k3d)로 이미지 임포트
Write-Header "Step 6/7: k3d 노드로 도커 이미지 임포트 중..."
$ClusterNode = (docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 cluster list --no-headers | ForEach-Object { $_.Split()[0] })
docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 image import `
  api-gateway:latest user-service:latest product-service:latest order-service:latest notification-service:latest `
  -c $ClusterNode
Write-Success "k3d 노드로 이미지 임포트 완료"

# 7. Kubernetes 리소스 배포
Write-Header "Step 7/7: Kubernetes 리소스 배포 중..."
& "$ProjectRoot\scripts\k8s-deploy.ps1"

Write-Header "🎉 LocalStack AWS EKS 배포가 성공적으로 완료되었습니다!"
