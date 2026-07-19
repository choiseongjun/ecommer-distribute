# PowerShell Script for Kubernetes Deployment
# Windows 환경용 Kubernetes 배포

Write-Host "=== Kubernetes Deployment for Big Data Platform ===" -ForegroundColor Yellow

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

# Kubernetes 클러스터 연결 확인
Print-Info "Kubernetes 클러스터 연결 확인..."
try {
    kubectl cluster-info | Out-Null
    Print-Success "Kubernetes 클러스터 연결 확인 완료"
} catch {
    Print-Error "Kubernetes 클러스터에 연결할 수 없습니다."
    Print-Info "kubectl config current-context를 확인하세요."
    exit 1
}

# 현재 디렉토리 저장
$CurrentDir = $PWD.Path

# 네임스페이스 생성
Print-Info "네임스페이스 생성..."
kubectl apply -f "$CurrentDir\k8s\00-namespace.yaml"
Print-Success "네임스페이스 생성 완료"

# ConfigMap 생성
Print-Info "ConfigMap 생성..."
kubectl apply -f "$CurrentDir\k8s\01-configmap.yaml"
Print-Success "ConfigMap 생성 완료"

# Secret 생성
Print-Info "Secret 생성..."
kubectl apply -f "$CurrentDir\k8s\02-secret.yaml"
Print-Success "Secret 생성 완료"

# PVC 생성
Print-Info "PersistentVolumeClaim 생성..."
kubectl apply -f "$CurrentDir\k8s\03-pvc.yaml"
Print-Success "PersistentVolumeClaim 생성 완료"

# StatefulSet 생성 (데이터베이스 및 메시지 브로커)
Print-Info "StatefulSet 생성 (데이터베이스 및 메시지 브로커)..."
kubectl apply -f "$CurrentDir\k8s\04-statefulset.yaml"
Print-Success "StatefulSet 생성 완료"

# 데이터베이스 시작 대기
Print-Info "데이터베이스 시작 대기 (최대 5분)..."
kubectl wait --for=condition=ready pod -l app=postgres -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=cassandra -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=zookeeper -n bigdataplatform --timeout=300s
kubectl wait --for=condition=ready pod -l app=kafka -n bigdataplatform --timeout=300s
Print-Success "데이터베이스 시작 완료"

# Deployment 생성 (인프라 서비스)
Print-Info "Deployment 생성 (인프라 서비스)..."
kubectl apply -f "$CurrentDir\k8s\05-deployment.yaml"
Print-Success "Deployment 생성 완료"

# 인프라 서비스 시작 대기
Print-Info "인프라 서비스 시작 대기 (최소 2분)..."
kubectl wait --for=condition=available deployment/consul -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/elasticsearch -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/prometheus -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/grafana -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/jaeger -n bigdataplatform --timeout=300s
Print-Success "인프라 서비스 시작 완료"

# Service 생성
Print-Info "Service 생성..."
kubectl apply -f "$CurrentDir\k8s\06-service.yaml"
Print-Success "Service 생성 완료"

# Ingress 생성 (선택사항)
Print-Info "Ingress 생성..."
$IngressClass = kubectl get ingressclass nginx 2>$null
if ($LASTEXITCODE -eq 0) {
    kubectl apply -f "$CurrentDir\k8s\07-ingress.yaml"
    Print-Success "Ingress 생성 완료"
} else {
    Print-Info "NGINX Ingress Controller가 설치되지 않아 Ingress를 건너뜁니다."
    Print-Info "LoadBalancer 타입의 Service를 사용하세요."
}

# 데이터베이스 초기화
Print-Info "데이터베이스 초기화..."

# PostgreSQL 초기화
Print-Info "PostgreSQL 데이터베이스 초기화..."
$PostgreSQLCheck = kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices -c "SELECT 1;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Print-Error "PostgreSQL 초기화 실패"
    exit 1
}

# PostgreSQL 스크립트 적용
if (Test-Path "$CurrentDir\scripts\setup-database.sql") {
    Get-Content "$CurrentDir\scripts\setup-database.sql" | kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices
    Print-Success "PostgreSQL 기본 스크립트 적용 완료"
}

if (Test-Path "$CurrentDir\scripts\complex-database.sql") {
    Get-Content "$CurrentDir\scripts\complex-database.sql" | kubectl exec -n bigdataplatform postgres-0 -- psql -U admin -d microservices
    Print-Success "PostgreSQL 복잡한 스크립트 적용 완료"
}

# Cassandra 초기화
Print-Info "Cassandra Keyspace 초기화..."
$CassandraCheck = kubectl exec -n bigdataplatform cassandra-0 -- cqlsh -e "DESCRIBE KEYSPACES;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Print-Error "Cassandra 초기화 실패"
    exit 1
}

if (Test-Path "$CurrentDir\scripts\setup-cassandra.cql") {
    Get-Content "$CurrentDir\scripts\setup-cassandra.cql" | kubectl exec -n bigdataplatform cassandra-0 -- cqlsh
    Print-Success "Cassandra 스크립트 적용 완료"
}

# Kafka 토픽 생성
Print-Info "Kafka 토픽 생성..."
kubectl exec -n bigdataplatform kafka-0 -- kafka-topics --create --if-not-exists --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --topic orders
Print-Success "Kafka 토픽 생성 완료"

# 마이크로서비스 시작 대기
Print-Info "마이크로서비스 시작 대기 (최소 2분)..."
kubectl wait --for=condition=available deployment/api-gateway -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/user-service -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/order-service -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/product-service -n bigdataplatform --timeout=300s
kubectl wait --for=condition=available deployment/notification-service -n bigdataplatform --timeout=300s
Print-Success "마이크로서비스 시작 완료"

# 배포 상태 확인
Print-Info "배포 상태 확인..."
kubectl get all -n bigdataplatform

Print-Success "Kubernetes 배포가 성공적으로 완료되었습니다!"
Write-Host ""
Print-Info "서비스 접속 정보:"
Write-Host "  - API Gateway: kubectl get svc api-gateway -n bigdataplatform"
Write-Host "  - Consul: kubectl get svc consul -n bigdataplatform"
Write-Host "  - Prometheus: kubectl get svc prometheus -n bigdataplatform"
Write-Host "  - Grafana: kubectl get svc grafana -n bigdataplatform"
Write-Host "  - Jaeger: kubectl get svc jaeger -n bigdataplatform"
Write-Host ""
Print-Info "포트 포워딩 예시:"
Write-Host "  kubectl port-forward -n bigdataplatform svc/api-gateway 8080:8080"
Write-Host "  kubectl port-forward -n bigdataplatform svc/consul 8500:8500"
Write-Host "  kubectl port-forward -n bigdataplatform svc/prometheus 9090:9090"
Write-Host "  kubectl port-forward -n bigdataplatform svc/grafana 3000:3000"
Write-Host "  kubectl port-forward -n bigdataplatform svc/jaeger 16686:16686"
