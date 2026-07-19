# PowerShell Script for Kubernetes Docker Image Build
# Windows 환경용 Kubernetes 배포 Docker 이미지 빌드

Write-Host "=== Docker Image Build for Kubernetes ===" -ForegroundColor Yellow

# 함수 정의
function Print-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Print-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Print-Info {
    param([string]$Message)
    Write-Host "→ $Message" -ForegroundColor Yellow
}

# Docker 설치 확인
Print-Info "Docker 설치 확인..."
try {
    docker --version | Out-Null
    Print-Success "Docker 설치 확인 완료"
} catch {
    Print-Error "Docker가 설치되지 않았습니다."
    exit 1
}

# Maven 설치 확인
Print-Info "Maven 설치 확인..."
try {
    mvn -version | Out-Null
    Print-Success "Maven 설치 확인 완료"
} catch {
    Print-Error "Maven가 설치되지 않았습니다."
    exit 1
}

# 현재 디렉토리 저장
$CurrentDir = Get-Location

# 마이크로서비스 빌드
Print-Info "마이크로서비스 빌드 시작..."

# API Gateway
Print-Info "API Gateway 빌드..."
Set-Location "$CurrentDir\services\api-gateway"
mvn clean package -DskipTests
docker build -t api-gateway:latest .
Set-Location $CurrentDir
Print-Success "API Gateway 빌드 완료"

# User Service
Print-Info "User Service 빌드..."
Set-Location "$CurrentDir\services\user-service"
mvn clean package -DskipTests
docker build -t user-service:latest .
Set-Location $CurrentDir
Print-Success "User Service 빌드 완료"

# Order Service
Print-Info "Order Service 빌드..."
Set-Location "$CurrentDir\services\order-service"
mvn clean package -DskipTests
docker build -t order-service:latest .
Set-Location $CurrentDir
Print-Success "Order Service 빌드 완료"

# Product Service
Print-Info "Product Service 빌드..."
Set-Location "$CurrentDir\services\product-service"
mvn clean package -DskipTests
docker build -t product-service:latest .
Set-Location $CurrentDir
Print-Success "Product Service 빌드 완료"

# Notification Service
Print-Info "Notification Service 빌드..."
Set-Location "$CurrentDir\services\notification-service"
mvn clean package -DskipTests
docker build -t notification-service:latest .
Set-Location $CurrentDir
Print-Success "Notification Service 빌드 완료"

# 이미지 확인
Print-Info "빌드된 이미지 확인..."
docker images | Select-String -Pattern "(api-gateway|user-service|order-service|product-service|notification-service)"

Print-Success "모든 Docker 이미지 빌드 완료!"
Write-Host ""
Print-Info "이미지를 Kubernetes 클러스터에 로드하세요:"
Write-Host "  - 로컬 클러스터 (minikube, kind): 이미지가 자동으로 사용됩니다"
Write-Host "  - 원격 클러스터: docker push 또는 kubectl apply를 사용하세요"
