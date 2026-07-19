#!/bin/bash

# Kubernetes Destroy Script
# Kubernetes에 배포된 모든 리소스 삭제

set -e

echo "=== Kubernetes Destroy for Big Data Platform ==="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수 정의
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# 경고 메시지
print_error "경고: 모든 리소스가 삭제됩니다!"
echo ""
print_info "계속 진행하시겠습니까? (yes/no)"
read -r response

if [[ "$response" != "yes" ]]; then
    print_info "삭제가 취소되었습니다."
    exit 0
fi

# Kubernetes 클러스터 연결 확인
print_info "Kubernetes 클러스터 연결 확인..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Kubernetes 클러스터에 연결할 수 없습니다."
    exit 1
fi
print_success "Kubernetes 클러스터 연결 확인 완료"

# 리소스 삭제 (역순)
print_info "Ingress 삭제..."
kubectl delete -f k8s/07-ingress.yaml --ignore-not-found=true
print_success "Ingress 삭제 완료"

print_info "Service 삭제..."
kubectl delete -f k8s/06-service.yaml --ignore-not-found=true
print_success "Service 삭제 완료"

print_info "Deployment 삭제..."
kubectl delete -f k8s/05-deployment.yaml --ignore-not-found=true
print_success "Deployment 삭제 완료"

print_info "StatefulSet 삭제..."
kubectl delete -f k8s/04-statefulset.yaml --ignore-not-found=true
print_success "StatefulSet 삭제 완료"

print_info "PersistentVolumeClaim 삭제..."
kubectl delete -f k8s/03-pvc.yaml --ignore-not-found=true
print_success "PersistentVolumeClaim 삭제 완료"

print_info "Secret 삭제..."
kubectl delete -f k8s/02-secret.yaml --ignore-not-found=true
print_success "Secret 삭제 완료"

print_info "ConfigMap 삭제..."
kubectl delete -f k8s/01-configmap.yaml --ignore-not-found=true
print_success "ConfigMap 삭제 완료"

print_info "네임스페이스 삭제..."
kubectl delete -f k8s/00-namespace.yaml --ignore-not-found=true
print_success "네임스페이스 삭제 완료"

# 남은 리소스 확인
print_info "남은 리소스 확인..."
kubectl get all -n bigdataplatform --ignore-not-found=true

print_success "모든 리소스가 성공적으로 삭제되었습니다!"
