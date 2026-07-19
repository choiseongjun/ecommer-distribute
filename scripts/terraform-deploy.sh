#!/bin/bash

# Terraform Deployment Script for LocalStack
# AWS 리소스를 LocalStack에 배포하는 스크립트

set -e

echo "=== Terraform Deployment for LocalStack ==="

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

# LocalStack 실행 확인
print_info "LocalStack 실행 상태 확인..."
if ! docker ps | grep -q localstack; then
    print_info "LocalStack을 시작합니다..."
    cd ..
    docker-compose up -d localstack
    print_info "LocalStack이 시작될 때까지 대기합니다..."
    sleep 10
    cd terraform
else
    print_success "LocalStack이 이미 실행 중입니다."
fi

# 테라폼 초기화
print_info "Terraform 초기화..."
terraform init -upgrade
print_success "Terraform 초기화 완료"

# 테라폼 포맷 검사
print_info "Terraform 포맷 검사..."
terraform fmt -check -recursive || {
    print_error "Terraform 포맷 오류가 있습니다."
    terraform fmt -recursive
    print_info "포맷이 자동 수정되었습니다."
}

# 테라폼 검증
print_info "Terraform 구성 검증..."
terraform validate
print_success "구성 검증 완료"

# 테라폼 플랜 생성
print_info "Terraform 실행 계획 생성..."
terraform plan -out=tfplan
print_success "실행 계획 생성 완료"

# 사용자 확인
echo ""
print_info "실행 계획을 검토하시겠습니까? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    terraform show tfplan
    echo ""
    print_info "계속 진행하시겠습니까? (y/n)"
    read -r confirm
    if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_error "배포가 취소되었습니다."
        exit 0
    fi
fi

# 테라폼 적용
print_info "Terraform 적용 중..."
terraform apply tfplan
print_success "Terraform 적용 완료"

# 출력 표시
print_info "배포된 리소스 정보:"
terraform output -json

# 정리
rm -f tfplan

print_success "배포가 성공적으로 완료되었습니다!"
echo ""
print_info "주요 엔드포인트:"
echo "  - LocalStack: http://localhost:4566"
echo "  - LocalStack Dashboard: http://localhost:4566/_dashboard"
echo ""
print_info "다음 명령어로 리소스를 확인할 수 있습니다:"
echo "  - terraform show"
echo "  - terraform output"
