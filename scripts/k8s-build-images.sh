#!/bin/bash

# Docker Image Build Script for Kubernetes
# Kubernetes 배포용 Docker 이미지 빌드

set -e

echo "=== Docker Image Build for Kubernetes ==="

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

# Docker 설치 확인
print_info "Docker 설치 확인..."
if ! command -v docker &> /dev/null; then
    print_error "Docker가 설치되지 않았습니다."
    exit 1
fi
print_success "Docker 설치 확인 완료"

# 마이크로서비스 빌드
print_info "마이크로서비스 빌드 시작..."

# API Gateway
print_info "API Gateway 빌드..."
cd services/api-gateway
mvn clean package -DskipTests
docker build -t api-gateway:latest .
cd ../..
print_success "API Gateway 빌드 완료"

# User Service
print_info "User Service 빌드..."
cd services/user-service
mvn clean package -DskipTests
docker build -t user-service:latest .
cd ../..
print_success "User Service 빌드 완료"

# Order Service
print_info "Order Service 빌드..."
cd services/order-service
mvn clean package -DskipTests
docker build -t order-service:latest .
cd ../..
print_success "Order Service 빌드 완료"

# Product Service
print_info "Product Service 빌드..."
cd services/product-service
mvn clean package -DskipTests
docker build -t product-service:latest .
cd ../..
print_success "Product Service 빌드 완료"

# Notification Service
print_info "Notification Service 빌드..."
cd services/notification-service
mvn clean package -DskipTests
docker build -t notification-service:latest .
cd ../..
print_success "Notification Service 빌드 완료"

# 이미지 확인
print_info "빌드된 이미지 확인..."
docker images | grep -E "(api-gateway|user-service|order-service|product-service|notification-service)"

print_success "모든 Docker 이미지 빌드 완료!"
echo ""
print_info "이미지를 Kubernetes 클러스터에 로드하세요:"
echo "  - 로컬 클러스터 (minikube, kind): 이미지가 자동으로 사용됩니다"
echo "  - 원격 클러스터: docker push 또는 kubectl apply를 사용하세요"
