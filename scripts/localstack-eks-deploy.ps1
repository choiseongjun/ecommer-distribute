# PowerShell Script for LocalStack EKS Deployment
# LocalStack AWS service simulation and Kubernetes integration

$ScriptPath = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptPath -Parent

Write-Host "=== LocalStack EKS Deployment for Big Data Platform ===" -ForegroundColor Yellow

# Check LocalStack status
Write-Host "Checking LocalStack status..." -ForegroundColor Yellow
$LocalStackRunning = docker ps | Select-String "localstack"
if (-not $LocalStackRunning) {
    Write-Host "Starting LocalStack..." -ForegroundColor Yellow
    Set-Location $ProjectRoot
    docker-compose up -d localstack
    Write-Host "Waiting for LocalStack to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
} else {
    Write-Host "LocalStack is already running." -ForegroundColor Green
}

# Check LocalStack connection
Write-Host "Checking LocalStack connection..." -ForegroundColor Yellow
try {
    $Response = Invoke-WebRequest -Uri "http://localhost:4566/_localstack/health" -UseBasicParsing
    if ($Response.StatusCode -eq 200) {
        Write-Host "LocalStack connection confirmed." -ForegroundColor Green
    } else {
        Write-Host "LocalStack connection failed." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "LocalStack connection failed: $_" -ForegroundColor Red
    exit 1
}

# Check Terraform installation
Write-Host "Checking Terraform installation..." -ForegroundColor Yellow
try {
    terraform --version | Out-Null
    Write-Host "Terraform installation confirmed." -ForegroundColor Green
} catch {
    Write-Host "Terraform is not installed." -ForegroundColor Red
    Write-Host "Install from https://www.terraform.io/downloads.html" -ForegroundColor Yellow
    exit 1
}

# Navigate to Terraform directory
$TerraformDir = Join-Path $ProjectRoot "terraform-aws"
if (-not (Test-Path $TerraformDir)) {
    Write-Host "terraform-aws directory not found." -ForegroundColor Red
    exit 1
}
Set-Location $TerraformDir

# Terraform init
Write-Host "Initializing Terraform..." -ForegroundColor Yellow
terraform init
Write-Host "Terraform initialized." -ForegroundColor Green

# Terraform plan
Write-Host "Creating Terraform execution plan..." -ForegroundColor Yellow
terraform plan -out=tfplan
Write-Host "Execution plan created." -ForegroundColor Green

# User confirmation
Write-Host ""
$Response = Read-Host "Continue with deployment? (y/n)"
if ($Response -ne "y" -and $Response -ne "Y") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    Set-Location $ProjectRoot
    exit 0
}

# Terraform apply
Write-Host "Applying Terraform configuration..." -ForegroundColor Yellow
terraform apply tfplan
Write-Host "Terraform apply completed." -ForegroundColor Green

# Show deployed resources
Write-Host "Checking deployed resources..." -ForegroundColor Yellow
terraform output

# Cleanup
Set-Location $ProjectRoot
$TfplanPath = Join-Path $TerraformDir "tfplan"
Remove-Item -Path $TfplanPath -ErrorAction SilentlyContinue

Write-Host "LocalStack AWS resource deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Deploy Kubernetes resources (kubectl apply -f k8s/)"
Write-Host "2. Check LocalStack resources with AWS CLI:"
Write-Host "   aws s3 ls --endpoint-url http://localhost:4566"
Write-Host "   aws rds describe-db-instances --endpoint-url http://localhost:4566"
Write-Host "3. RDS endpoint: localhost:4566"
Write-Host "4. Redis endpoint: localhost:4566"
