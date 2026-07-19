# PowerShell Script for LocalStack EKS kubeconfig Setup
# LocalStack EKS 클러스터에 kubectl 연결 설정

Write-Host "=== LocalStack EKS kubeconfig Setup ===" -ForegroundColor Yellow

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

# LocalStack 연결 확인
Print-Info "LocalStack 연결 확인..."
try {
    $Response = Invoke-WebRequest -Uri "http://localhost:4566/_localstack/health" -UseBasicParsing
    if ($Response.StatusCode -eq 200) {
        Print-Success "LocalStack 연결 확인 완료"
    } else {
        Print-Error "LocalStack 연결 실패"
        exit 1
    }
} catch {
    Print-Error "LocalStack 연결 실패: $_"
    exit 1
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

# AWS CLI LocalStack 설정
Print-Info "AWS CLI LocalStack 설정..."
aws configure set aws_access_key_id test
aws configure set aws_secret_access_key test
aws configure set default.region ap-northeast-2
aws configure set default.output json

# LocalStack 엔드포인트 설정
$Env:AWS_ENDPOINT_URL = "http://localhost:4566"
Print-Success "AWS CLI LocalStack 설정 완료"

# LocalStack EKS 클러스터 정보 확인
Print-Info "LocalStack EKS 클러스터 정보 확인..."
try {
    $Clusters = aws eks list-clusters --endpoint-url http://localhost:4566 --region ap-northeast-2 | ConvertFrom-Json
    if ($Clusters.clusters) {
        Print-Success "EKS 클러스터 확인 완료: $($Clusters.clusters -join ', ')"
    } else {
        Print-Info "EKS 클러스터가 없습니다. 먼저 Terraform으로 배포하세요."
        exit 1
    }
} catch {
    Print-Error "EKS 클러스터 확인 실패: $_"
    exit 1
}

# kubeconfig 업데이트
Print-Info "kubeconfig 업데이트..."
$ClusterName = $Clusters.clusters[0]
aws eks update-kubeconfig --name $ClusterName --endpoint-url http://localhost:4566 --region ap-northeast-2
Print-Success "kubeconfig 업데이트 완료"

# 클러스터 연결 확인
Print-Info "클러스터 연결 확인..."
kubectl cluster-info
kubectl get nodes
Print-Success "클러스터 연결 확인 완료"

Print-Success "LocalStack EKS kubeconfig 설정이 완료되었습니다!"
Write-Host ""
Print-Info "다음 명령어로 클러스터를 관리할 수 있습니다:"
Write-Host "  kubectl get pods"
Write-Host "  kubectl get svc"
Write-Host "  kubectl apply -f k8s/"
