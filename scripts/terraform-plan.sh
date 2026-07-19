#!/bin/bash

# Terraform Plan Script for LocalStack
# 배포 전 실행 계획을 확인하는 스크립트

set -e

echo "=== Terraform Plan for LocalStack ==="

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

# 디렉토리 확인
if [ ! -d "terraform" ]; then
    print_error "terraform 디렉토리를 찾을 수 없습니다."
    exit 1
fi

cd terraform

# 테라폼 초기화
print_info "Terraform 초기화..."
terraform init -upgrade
print_success "Terraform 초기화 완료"

# 테라폼 플랜 생성
print_info "Terraform 실행 계획 생성..."
terraform plan -out=tfplan
print_success "실행 계획 생성 완료"

# 플랜 표시
print_info "실행 계획 상세:"
terraform show tfplan

# 정리
rm -f tfplan

print_success "실행 계획 확인 완료"
