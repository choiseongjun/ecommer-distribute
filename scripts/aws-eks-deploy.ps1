# PowerShell Script for AWS EKS Deployment
# 실제 AWS 환경에 EKS 클러스터 및 마이크로서비스 배포

Write-Host "=== AWS EKS Deployment for Big Data Platform ===" -ForegroundColor Yellow

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

# AWS CLI 설치 확인
Print-Info "AWS CLI 설치 확인..."
try {
    aws --version | Out-Null
    Print-Success "AWS CLI 설치 확인 완료"
} catch {
    Print-Error "AWS CLI가 설치되지 않았습니다."
    Print-Info "https://aws.amazon.com/cli/ 에서 설치하세요."
    exit 1
}

# Terraform 설치 확인
Print-Info "Terraform 설치 확인..."
try {
    terraform --version | Out-Null
    Print-Success "Terraform 설치 확인 완료"
} catch {
    Print-Error "Terraform이 설치되지 않았습니다."
    Print-Info "https://www.terraform.io/downloads.html 에서 설치하세요."
    exit 1
}

# kubectl 설치 확인
Print-Info "kubectl 설치 확인..."
try {
    kubectl version --client | Out-Null
    Print-Success "kubectl 설치 확인 완료"
} catch {
    Print-Error "kubectl이 설치되지 않았습니다."
    Print-Info "https://kubernetes.io/docs/tasks/tools/ 에서 설치하세요."
    exit 1
}

# 현재 디렉토리 저장
$CurrentDir = Get-Location

# Terraform 디렉토리로 이동
Set-Location "$CurrentDir\terraform-aws"

# Terraform 초기화
Print-Info "Terraform 초기화..."
terraform init
Print-Success "Terraform 초기화 완료"

# Terraform 플랜 생성
Print-Info "Terraform 실행 계획 생성..."
terraform plan -out=tfplan
Print-Success "실행 계획 생성 완료"

# 사용자 확인
Write-Host ""
Print-Info "계속 진행하시겠습니까? (y/n)"
$Response = Read-Host
if ($Response -ne "y" -and $Response -ne "Y") {
    Print-Info "배포가 취소되었습니다."
    Set-Location $CurrentDir
    exit 0
}

# Terraform 적용
Print-Info "Terraform 적용 중..."
terraform apply tfplan
Print-Success "Terraform 적용 완료"

# kubeconfig 업데이트
Print-Info "kubeconfig 업데이트..."
aws eks update-kubeconfig --name bigdataplatform-eks --region ap-northeast-2
Print-Success "kubeconfig 업데이트 완료"

# 클러스터 연결 확인
Print-Info "클러스터 연결 확인..."
kubectl cluster-info
Print-Success "클러스터 연결 확인 완료"

# ECR 로그인
Print-Info "ECR 로그인..."
$AccountId = aws sts get-caller-identity --query Account --output text
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin "$AccountId.dkr.ecr.ap-northeast-2.amazonaws.com"
Print-Success "ECR 로그인 완료"

# 정리
Set-Location $CurrentDir
Remove-Item -Path terraform-aws\tfplan -ErrorAction SilentlyContinue

Print-Success "AWS EKS 인프라 배포가 완료되었습니다!"
Write-Host ""
Print-Info "다음 단계:"
Write-Host "1. Docker 이미지를 ECR에 푸시하세요"
Write-Host "2. Kubernetes 매니페스트를 배포하세요"
Write-Host "3. ALB DNS 주소로 접속하세요"
