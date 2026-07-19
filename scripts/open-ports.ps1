# EKS Kubernetes Port Forwarding Automation Script
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "🚀 Opening All EKS Service Ports (Port-Forwarding)" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. API Gateway (Port 8080)
Start-Process powershell -ArgumentList "-Command kubectl port-forward -n bigdataplatform service/api-gateway 8080:8080" -WindowStyle Hidden
Write-Host "[OK] API Gateway forwarded to http://localhost:8080" -ForegroundColor Green

# 2. Grafana Dashboard (Port 3000)
Start-Process powershell -ArgumentList "-Command kubectl port-forward -n bigdataplatform service/grafana 3000:3000" -WindowStyle Hidden
Write-Host "[OK] Grafana Dashboard forwarded to http://localhost:3000 (admin / admin)" -ForegroundColor Green

# 3. Jaeger Tracing (Port 16686)
Start-Process powershell -ArgumentList "-Command kubectl port-forward -n bigdataplatform service/jaeger 16686:16686" -WindowStyle Hidden
Write-Host "[OK] Jaeger Distributed Tracing forwarded to http://localhost:16686" -ForegroundColor Green

# 4. Prometheus Engine (Port 9090)
Start-Process powershell -ArgumentList "-Command kubectl port-forward -n bigdataplatform service/prometheus 9090:9090" -WindowStyle Hidden
Write-Host "[OK] Prometheus Metrics Engine forwarded to http://localhost:9090" -ForegroundColor Green

# 5. Consul Discovery (Port 8500)
Start-Process powershell -ArgumentList "-Command kubectl port-forward -n bigdataplatform service/consul 8500:8500" -WindowStyle Hidden
Write-Host "[OK] Consul Service Discovery forwarded to http://localhost:8500" -ForegroundColor Green

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "All ports opened successfully! Access UIs in your browser." -ForegroundColor Yellow
