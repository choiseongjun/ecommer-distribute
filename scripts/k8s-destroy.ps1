# PowerShell Script for Kubernetes Destroy
# Windows 환경용 Kubernetes 리소스 삭제

Write-Host "=== Kubernetes Destroy for Big Data Platform ===" -ForegroundColor Yellow

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

# 경고 메시지
Print-Error "경고: 모든 리소스가 삭제됩니다!"
Write-Host ""
$Response = Read-Host "계속 진행하시겠습니까? (yes/no)"

if ($Response -ne "yes") {
    Print-Info "삭제가 취소되었습니다."
    exit 0
}

# Kubernetes 클러스터 연결 확인
Print-Info "Kubernetes 클러스터 연결 확인..."
try {
    kubectl cluster-info | Out-Null
    Print-Success "Kubernetes 클러스터 연결 확인 완료"
} catch {
    Print-Error "Kubernetes 클러스터에 연결할 수 없습니다."
    exit 1
}

# 현재 디렉토리 저장
$CurrentDir = Get-Location

# 리소스 삭제 (역순)
Print-Info "Ingress 삭제..."
kubectl delete -f "$CurrentDir\k8s\07-ingress.yaml" --ignore-not-found=true
Print-Success "Ingress 삭제 완료"

Print-Info "Service 삭제..."
kubectl delete -f "$CurrentDir\k8s\06-service.yaml" --ignore-not-found=true
Print-Success "Service 삭제 완료"

Print-Info "Deployment 삭제..."
kubectl delete -f "$CurrentDir\k8s\05-deployment.yaml" --ignore-not-found=true
Print-Success "Deployment 삭제 완료"

Print-Info "StatefulSet 삭제..."
kubectl delete -f "$CurrentDir\k8s\04-statefulset.yaml" --ignore-not-found=true
Print-Success "StatefulSet 삭제 완료"

Print-Info "PersistentVolumeClaim 삭제..."
kubectl delete -f "$CurrentDir\k8s\03-pvc.yaml" --ignore-not-found=true
Print-Success "PersistentVolumeClaim 삭제 완료"

Print-Info "Secret 삭제..."
kubectl delete -f "$CurrentDir\k8s\02-secret.yaml" --ignore-not-found=true
Print-Success "Secret 삭제 완료"

Print-Info "ConfigMap 삭제..."
kubectl delete -f "$CurrentDir\k8s\01-configmap.yaml" --ignore-not-found=true
Print-Success "ConfigMap 삭제 완료"

Print-Info "네임스페이스 삭제..."
kubectl delete -f "$CurrentDir\k8s\00-namespace.yaml" --ignore-not-found=true
Print-Success "네임스페이스 삭제 완료"

# 남은 리소스 확인
Print-Info "남은 리소스 확인..."
kubectl get all -n bigdataplatform --ignore-not-found=true

Print-Success "모든 리소스가 성공적으로 삭제되었습니다!"
