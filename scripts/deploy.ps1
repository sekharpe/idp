# Build and Deploy Script for CNOE Platform (Windows/PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "🚀 CNOE Platform - Automated Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host "`n📋 Checking prerequisites..." -ForegroundColor Yellow

$commands = @("az", "terraform", "kubectl", "docker")
foreach ($cmd in $commands) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "❌ $cmd not found. Please install it first." -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All prerequisites met" -ForegroundColor Green

# Step 1: Deploy Infrastructure
Write-Host "`n📦 Step 1: Deploying Azure Infrastructure..." -ForegroundColor Yellow
Set-Location infrastructure\azure\terraform

terraform init
terraform apply -auto-approve

# Get outputs
$RG_NAME = terraform output -raw resource_group_name
$AKS_NAME = terraform output -raw aks_cluster_name
$ACR_NAME = terraform output -raw acr_name
$ACR_LOGIN_SERVER = terraform output -raw acr_login_server

Write-Host "✅ Infrastructure deployed" -ForegroundColor Green
Write-Host "   Resource Group: $RG_NAME"
Write-Host "   AKS Cluster: $AKS_NAME"
Write-Host "   ACR: $ACR_NAME"

# Step 2: Get AKS credentials
Write-Host "`n🔑 Step 2: Configuring kubectl..." -ForegroundColor Yellow
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME --overwrite-existing

kubectl get nodes
Write-Host "✅ kubectl configured" -ForegroundColor Green

# Step 3: Deploy ArgoCD
Write-Host "`n🔄 Step 3: Deploying ArgoCD..." -ForegroundColor Yellow
Set-Location ..\..\..
kubectl apply -k infrastructure\kubernetes\argocd\base

Write-Host "⏳ Waiting for ArgoCD to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

$ARGOCD_PASSWORD_B64 = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
$ARGOCD_PASSWORD = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($ARGOCD_PASSWORD_B64))

Write-Host "✅ ArgoCD deployed" -ForegroundColor Green
Write-Host "   Admin password: $ARGOCD_PASSWORD"

# Step 4: Build and push container
Write-Host "`n🐳 Step 4: Building and pushing CNOE platform container..." -ForegroundColor Yellow
Set-Location containers\platform-services

az acr login --name $ACR_NAME

docker build -f Dockerfile.cnoe -t cnoe-platform-services:latest .
docker tag cnoe-platform-services:latest "$ACR_LOGIN_SERVER/cnoe-platform-services:latest"
docker push "$ACR_LOGIN_SERVER/cnoe-platform-services:latest"

Write-Host "✅ Container built and pushed" -ForegroundColor Green

# Step 5: Update deployment with ACR
Write-Host "`n⚙️  Step 5: Updating Kubernetes manifests..." -ForegroundColor Yellow
Set-Location ..\..

$deploymentFile = "infrastructure\kubernetes\cnoe-platform\deployment.yaml"
$content = Get-Content $deploymentFile -Raw
$content = $content -replace "cnoedevacr.azurecr.io", $ACR_LOGIN_SERVER
Set-Content $deploymentFile -Value $content

Write-Host "✅ Manifests updated" -ForegroundColor Green

# Step 6: Deploy CNOE platform
Write-Host "`n🎯 Step 6: Deploying CNOE platform services..." -ForegroundColor Yellow
kubectl apply -k infrastructure\kubernetes\cnoe-platform

Write-Host "⏳ Waiting for CNOE platform to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=cnoe-platform -n cnoe-platform --timeout=300s

Write-Host "✅ CNOE platform deployed" -ForegroundColor Green

# Step 7: Deploy Backstage
Write-Host "`n🎭 Step 7: Deploying Backstage (IDP)..." -ForegroundColor Yellow
kubectl apply -k infrastructure\kubernetes\backstage

Write-Host "⏳ Waiting for Backstage to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=600s

Write-Host "✅ Backstage deployed" -ForegroundColor Green

# Step 8: Deploy Ingress
Write-Host "`n🌐 Step 8: Deploying NGINX Ingress..." -ForegroundColor Yellow
kubectl apply -k infrastructure\kubernetes\ingress

Write-Host "⏳ Waiting for ingress controller..." -ForegroundColor Yellow
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=120s

Write-Host "✅ Ingress deployed" -ForegroundColor Green

# Summary
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "✨ CNOE Platform Deployment Complete! ✨" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "`n📊 Cluster Status:" -ForegroundColor Yellow
kubectl get pods -A | Select-String -Pattern "NAMESPACE|argocd|cnoe-platform|ingress-nginx"

Write-Host "`n🔗 Access URLs (using port-forward):" -ForegroundColor Yellow
Write-Host "   Backstage: kubectl port-forward -n backstage svc/backstage 7007:7007"
Write-Host "             Then open: http://localhost:7007"
Write-Host ""
Write-Host "   Portal:    kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8081:8081"
Write-Host "             Then open: http://localhost:8081"
Write-Host ""
Write-Host "   API:       kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8080:8080"
Write-Host "             Then open: http://localhost:8080/api/info"
Write-Host ""
Write-Host "   ArgoCD:    kubectl port-forward svc/argocd-server -n argocd 8443:443"
Write-Host "             Then open: https://localhost:8443"
Write-Host "             Username: admin"
Write-Host "             Password: $ARGOCD_PASSWORD"

Write-Host "`n💰 Estimated Monthly Cost: ~`$40-50 USD" -ForegroundColor Yellow

Write-Host "`n📖 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Access Backstage and configure integrations"
Write-Host "   2. Create Azure landing zones using templates"
Write-Host "   3. Configure Azure DevOps/GitHub service connections"
Write-Host "   4. Register existing services in catalog"

Write-Host "`n📚 Documentation:" -ForegroundColor Yellow
Write-Host "   - Setup Guide: docs\SETUP_GUIDE.md"
Write-Host "   - Quick Start: docs\QUICKSTART.md"
Write-Host ""
