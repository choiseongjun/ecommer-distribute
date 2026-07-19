#!/bin/bash

# Kubernetes Deployment Script
# 전체 마이크로서비스 플랫폼을 Kubernetes에 배포

set -e

echo "=== Kubernetes Deployment for Big Data Platform ==="

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

# Kubernetes 클러스터 연결 확인
print_info "Kubernetes 클러스터 연결 확인..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Kubernetes 클러스터에 연결할 수 없습니다."
    print_info "kubectl config current-context를 확인하세요."
    exit 1
fi
print_success "Kubernetes 클러스터 연결 확인 완료"

# 네임스페이스 생성
print_info "네임스페이스 생성..."
kubectl apply -f k8s/00-namespace.yaml
print_success "네임스페이스 생성 완료"

# ConfigMap 생성
print_info "ConfigMap 생성..."
kubectl apply -f k8s/01-configmap.yaml
print_success "ConfigMap 생성 완료"

# Secret 생성
print_info "Secret 생성..."
kubectl apply -f k8s/02-secret.yaml
print_success "Secret 생성 완료"

# PVC 생성
print_info "PersistentVolumeClaim 생성..."
kubectl apply -f k8s/03-pvc.yaml
print_success "PersistentVolumeClaim 생성 완료"

# StatefulSet 생성 (데이터베이스 및 메시지 브로커)
print_info "StatefulSet 생성 (데이터베이스 및 메시지 브로커)..."
kubectl apply -f k8s/04-statefulset.yaml
print_success "StatefulSet 생성 완료"

# 데이터베이스 시작 대기
print_info "데이터베이스 시작 대기 (최대 5분)..."
kubectl wait --for=condition=ready pod -l app=postgres -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=cassandra -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=zookeeper -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=kafka -n bigdataplatform --timeout=300s
print_success "데이터베이스 시작 완료"

# Deployment 생성 (인프라 서비스)
print_info "Deployment 생성 (인프라 서비스)..."
kubectl apply -f k8s/05-deployment.yaml
print_success "Deployment 생성 완료"

# 인프라 서비스 시작 대기
print_info "인프라 서비스 시작 대기 (최소 2분)..."
kubectl wait --for=condition=available deployment/consul -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/elasticsearch -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/prometheus -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/grafana -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/jaeger -n bigdataplatform --timeout=300s
print_success "인프라 서비스 시작 완료"

# Service 생성
print_info "Service 생성..."
kubectl apply -f k8s/06-service.yaml
print_success "Service 생성 완료"

# Ingress 생성 (선택사항)
print_info "Ingress 생성..."
if kubectl get ingressclass nginx &> /dev/null; then
    kubectl apply -f k8s/07-ingress.yaml
    print_success "Ingress 생성 완료"
else
    print_info "NGINX Ingress Controller가 설치되지 않아 Ingress를 건너뜁니다."
    print_info "LoadBalancer 타입의 Service를 사용하세요."
fi

# 데이터베이스 초기화
print_info "데이터베이스 초기화..."

# PostgreSQL 초기화
print_info "PostgreSQL 데이터베이스 초기화..."
kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices -c "SELECT 1;" &> /dev/null || {
    print_error "PostgreSQL 초기화 실패"
    exit 1
}

# PostgreSQL 스크립트 적용
if [ -f "scripts/setup-database.sql" ]; then
    kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices < scripts/setup-database.sql
    print_success "PostgreSQL 기본 스크립트 적용 완료"
fi

if [ -f "scripts/complex-database.sql" ]; then
    kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices < scripts/complex-database.sql
    print_success "PostgreSQL 복잡한 스크립트 적용 완료"
fi

# Cassandra 초기화
print_info "Cassandra Keyspace 초기화..."
kubectl exec -n bigdataplatform cassandra-0 -- cqlsh -e "DESCRIBE KEYSPACES;" &> /dev/null || {
    print_error "Cassandra 초기화 실패"
    exit 1
}

if [ -f "scripts/setup-cassandra.cql" ]; then
    kubectl exec -n bigdataplatform cassandra-0 -- cqlsh < scripts/setup-cassandra.cql
    print_success "Cassandra 스크립트 적용 완료"
fi

# Kafka 토픽 생성
print_info "Kafka 토픽 생성..."
kubectl exec -n bigdataplatform kafka-0 -- kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --topic orders
print_success "Kafka 토픽 생성 완료"

# 마이크로서비스 시작 대기
print_info "마이크로서비스 시작 대기 (최소 2분)..."
kubectl wait --for=condition=available deployment/api-gateway -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/user-service -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/order-service -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/product-service -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/notification-service -n bigdataplatform --timeout=300s
print_success "마이크로서비스 시작 완료"

# 배포 상태 확인
print_info "배포 상태 확인..."
kubectl get all -n bigdataplatform

print_success "Kubernetes 배포가 성공적으로 완료되었습니다!"
echo ""
print_info "서비스 접속 정보:"
echo "  - API Gateway: kubectl get svc api-gateway -n bigdataplatform"
echo "  - Consul: kubectl get svc consul -n bigdataplatform"
echo "  - Prometheus: kubectl get svc prometheus -n bigdataplatform"
echo "  - Grafana: kubectl get svc grafana -n bigdataplatform"
echo "  - Jaeger: kubectl get svc jaeger -n bigdataplatform"
echo ""
print_info "포트 포워딩 예시:"
echo "  kubectl port-forward -n bigdataplatform svc/api-gateway 8080:8080"
echo "  kubectl port-forward -n bigdataplatform svc/consul 8500:8500"
echo "  kubectl port-forward -n bigdataplatform svc/prometheus 9090:9090"
echo "  kubectl port-forward -n bigdataplatform svc/grafana 3000:3000"
echo "  kubectl port-forward -n bigdataplatform svc/jaeger 16686:16686"
