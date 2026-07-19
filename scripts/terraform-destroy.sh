#!/bin/bash

# Terraform Destroy Script for LocalStack
# LocalStack에 배포된 AWS 리소스를 삭제하는 스크립트

set -e

echo "=== Terraform Destroy for LocalStack ==="

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

# 경고 메시지
print_error "경고: 모든 리소스가 삭제됩니다!"
echo ""
print_info "계속 진행하시겠습니까? (yes/no)"
read -r response

if [[ "$response" != "yes" ]]; then
    print_info "삭제가 취소되었습니다."
    exit 0
fi

# 테라폼 삭제
print_info "Terraform 리소스 삭제 중..."
terraform destroy -auto-approve
print_success "리소스 삭제 완료"

print_success "모든 리소스가 성공적으로 삭제되었습니다!"
