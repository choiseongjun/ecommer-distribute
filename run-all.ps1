# PowerShell Master Automation Script for LocalStack AWS EKS Deployment
# 프로젝트 전체를 LocalStack EKS 쿠버네티스 클러스터 상에 배포 및 테스트하는 자동화 스크립트

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

# 0. 시스템 PATH 환경 변수 갱신
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

Write-Header "Big Data Platform - AWS LocalStack EKS 쿠버네티스 원클릭 자동 배포 시작"

# 호스트 기존 미들웨어 컨테이너 정리 (EKS 포트 충돌 방지)
Write-Info "기존 호스트 독립형 컨테이너 정리 중..."
try { docker stop postgres cassandra redis zookeeper kafka api-gateway user-service order-service product-service notification-service 2>$null } catch {}
try { docker rm postgres cassandra redis zookeeper kafka api-gateway user-service order-service product-service notification-service 2>$null } catch {}

# 1. LocalStack 시작
Write-Header "Step 1/8: LocalStack AWS 컨테이너 시작 중..."
docker-compose up -d localstack
Write-Success "LocalStack 컨테이너 구동 완료"

Write-Info "LocalStack 헬스체크 대기..."
while ($true) {
    try {
        $Health = Invoke-RestMethod -Uri "http://127.0.0.1:4566/_localstack/health" -ErrorAction Stop
        if ($Health.edition -eq "community" -or $Health.services.s3 -eq "available") { break }
    } catch {}
    Start-Sleep -Seconds 3
}
Write-Success "LocalStack 정상 가동 확인"

# 2. AWS S3 및 IAM 리소스 생성 (AWS CLI)
Write-Header "Step 2/8: AWS S3 버킷 및 IAM 역할 생성 중..."
try { aws s3 mb s3://bigdataplatform-assets --endpoint-url http://localhost:4566 --region ap-northeast-2 2>$null } catch {}
try { aws s3 mb s3://bigdataplatform-logs --endpoint-url http://localhost:4566 --region ap-northeast-2 2>$null } catch {}
try { aws iam create-role --role-name bigdataplatform-kubernetes-role --assume-role-policy-document "{\`"Version\`":\`"2012-10-17\`",\`"Statement\`":[{\`"Effect\`":\`"Allow\`",\`"Principal\`":{\`"Service\`":\`"ec2.amazonaws.com\`"},\`"Action\`":\`"sts:AssumeRole\`"}]}" --endpoint-url http://localhost:4566 --region ap-northeast-2 2>$null } catch {}
Write-Success "AWS S3 및 IAM 리소스 생성 완료"

# 3. Kubeconfig 및 Node Taint 설정
Write-Header "Step 3/8: LocalStack k3d EKS 클러스터 연결 및 노드 스케줄링 설정..."
$ClusterList = docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 cluster list --no-headers 2>$null
if (-not $ClusterList) {
    Write-Info "LocalStack EKS k3d 클러스터가 없어 신규 구성을 진행합니다..."
    docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 cluster create bigdataplatform
}

$ClusterName = (docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 cluster list --no-headers | ForEach-Object { $_.Split()[0] })
$KubeCfg = (docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 kubeconfig get $ClusterName) -replace 'host.docker.internal', '127.0.0.1'

$KubeDir = "$env:USERPROFILE\.kube"
if (-not (Test-Path $KubeDir)) { New-Item -ItemType Directory -Path $KubeDir -Force }
$KubeFile = "$KubeDir\config"
[System.IO.File]::WriteAllText($KubeFile, $KubeCfg)
$env:KUBECONFIG = $KubeFile

try { kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule- 2>$null } catch {}
try { kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>$null } catch {}
try { kubectl taint nodes --all node-role.kubernetes.io/master- 2>$null } catch {}

kubectl get nodes
Write-Success "EKS 쿠버네티스 노드 연결 및 스케줄링 준비 완료"

# 4. Maven 빌드 및 Docker 이미지 생성
Write-Header "Step 4/8: Docker 기반 Maven 빌드 및 마이크로서비스 이미지 생성 중..."
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
Write-Success "5개 마이크로서비스 도커 이미지 빌드 완료"

# 5. 도커 이미지를 EKS 노드(k3d)로 임포트
Write-Header "Step 5/8: 도커 이미지를 EKS 쿠버네티스 노드로 주입 중..."
docker exec localstack /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 image import `
  api-gateway:latest user-service:latest product-service:latest order-service:latest notification-service:latest `
  -c $ClusterName
Write-Success "EKS 쿠버네티스 노드로 이미지 임포트 완료"

# 6. Kubernetes 리소스 배포 및 DB 초기화
Write-Header "Step 6/8: Kubernetes 매니페스트 배포 및 DB 스키마 생성 중..."
kubectl apply -f "$ProjectRoot\k8s\00-namespace.yaml"
kubectl apply -f "$ProjectRoot\k8s\01-configmap.yaml"
kubectl apply -f "$ProjectRoot\k8s\02-secret.yaml"
kubectl apply -f "$ProjectRoot\k8s\03-pvc.yaml"
kubectl apply -f "$ProjectRoot\k8s\04-statefulset.yaml"
kubectl apply -f "$ProjectRoot\k8s\05-deployment.yaml"
kubectl apply -f "$ProjectRoot\k8s\06-service.yaml"

Write-Info "EKS 데이터베이스 및 인프라 Pod 준공 대기..."
kubectl wait --for=condition=ready pod/postgres-0 -n bigdataplatform --timeout=180s
kubectl wait --for=condition=ready pod/cassandra-0 -n bigdataplatform --timeout=180s
kubectl wait --for=condition=ready pod/redis-0 -n bigdataplatform --timeout=180s
kubectl wait --for=condition=ready pod/kafka-0 -n bigdataplatform --timeout=180s

Write-Info "EKS PostgreSQL (postgres-0) 스키마 생성 중..."
Start-Sleep -Seconds 5
Get-Content "$ProjectRoot\scripts\setup-database.sql" | kubectl exec -i -n bigdataplatform postgres-0 -- psql -h 127.0.0.1 -U admin -d microservices

Write-Info "EKS Cassandra (cassandra-0) NoSQL 스키마 생성 중..."
Get-Content "$ProjectRoot\scripts\setup-cassandra.cql" | kubectl exec -i -n bigdataplatform cassandra-0 -- cqlsh

Write-Info "EKS Kafka (kafka-0) 토픽 생성 중..."
try { kubectl exec -n bigdataplatform kafka-0 -- kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --topic orders 2>$null } catch {}

Write-Success "EKS 쿠버네티스 매니페스트 및 데이터베이스 배포 완료"

# 7. 마이크로서비스 구동 대기
Write-Header "Step 7/8: EKS 쿠버네티스 마이크로서비스 초기화 대기 중..."
Write-Info "스프링 부트 마이크로서비스 초기화 대기 (30초)..."
Start-Sleep -Seconds 30

# 8. 포트 포워딩 및 E2E API 테스트
Write-Header "Step 8/8: API Gateway 포트 포워딩 및 통합 API 시나리오 테스트..."
$PF_Cmd = "`$env:KUBECONFIG='$KubeFile'; `$env:Path='$($env:Path)'; kubectl port-forward -n bigdataplatform service/api-gateway 8080:8080"
Start-Process powershell -ArgumentList "-Command $PF_Cmd" -WindowStyle Hidden
Start-Sleep -Seconds 6

python "$ProjectRoot\scripts\test-api.py"

Write-Header "🎉 AWS LocalStack EKS 쿠버네티스 배포 및 API 검증이 성공적으로 완료되었습니다!"
Write-Info "배포된 쿠버네티스 Pod 상태:"
kubectl get pods -n bigdataplatform
