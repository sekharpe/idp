# Build and Deploy Script for CNOE Platform

# Exit on error
set -e

echo "🚀 CNOE Platform - Automated Deployment"
echo "========================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI not found. Install from https://aka.ms/azure-cli"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found. Install from https://www.terraform.io/downloads"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker not found. Install from https://docs.docker.com/get-docker/"; exit 1; }

echo "✅ All prerequisites met"

# Step 1: Deploy Infrastructure
echo ""
echo "📦 Step 1: Deploying Azure Infrastructure..."
cd infrastructure/azure/terraform

terraform init
terraform apply -auto-approve

# Get outputs
RG_NAME=$(terraform output -raw resource_group_name)
AKS_NAME=$(terraform output -raw aks_cluster_name)
ACR_NAME=$(terraform output -raw acr_name)
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)

echo "✅ Infrastructure deployed"
echo "   Resource Group: $RG_NAME"
echo "   AKS Cluster: $AKS_NAME"
echo "   ACR: $ACR_NAME"

# Step 2: Get AKS credentials
echo ""
echo "🔑 Step 2: Configuring kubectl..."
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME --overwrite-existing

kubectl get nodes
echo "✅ kubectl configured"

# Step 3: Deploy ArgoCD
echo ""
echo "🔄 Step 3: Deploying ArgoCD..."
cd ../../..
kubectl apply -k infrastructure/kubernetes/argocd/base

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "✅ ArgoCD deployed"
echo "   Admin password: $ARGOCD_PASSWORD"

# Step 4: Build and push container
echo ""
echo "🐳 Step 4: Building and pushing CNOE platform container..."
cd containers/platform-services

az acr login --name $ACR_NAME

docker build -f Dockerfile.cnoe -t cnoe-platform-services:latest .
docker tag cnoe-platform-services:latest $ACR_LOGIN_SERVER/cnoe-platform-services:latest
docker push $ACR_LOGIN_SERVER/cnoe-platform-services:latest

echo "✅ Container built and pushed"

# Step 5: Update deployment with ACR
echo ""
echo "⚙️  Step 5: Updating Kubernetes manifests..."
cd ../..

# Update deployment.yaml with correct ACR
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|cnoedevacr.azurecr.io|$ACR_LOGIN_SERVER|g" infrastructure/kubernetes/cnoe-platform/deployment.yaml
else
    # Linux
    sed -i "s|cnoedevacr.azurecr.io|$ACR_LOGIN_SERVER|g" infrastructure/kubernetes/cnoe-platform/deployment.yaml
fi

echo "✅ Manifests updated"

# Step 6: Deploy CNOE platform
echo ""
echo "🎯 Step 6: Deploying CNOE platform services..."
kubectl apply -k infrastructure/kubernetes/cnoe-platform

echo "⏳ Waiting for CNOE platform to be ready..."
kubectl wait --for=condition=ready pod -l app=cnoe-platform -n cnoe-platform --timeout=300s

echo "✅ CNOE platform deployed"

# Step 7: Deploy Backstage
echo ""
echo "🎭 Step 7: Deploying Backstage (IDP)..."
kubectl apply -k infrastructure/kubernetes/backstage

echo "⏳ Waiting for Backstage to be ready..."
kubectl wait --for=condition=ready pod -l app=backstage -n backstage --timeout=600s

echo "✅ Backstage deployed"

# Step 8: Deploy Ingress
echo ""
echo "🌐 Step 8: Deploying NGINX Ingress..."
kubectl apply -k infrastructure/kubernetes/ingress

echo "⏳ Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "✅ Ingress deployed"

# Summary
echo ""
echo "=========================================="
echo "✨ CNOE Platform Deployment Complete! ✨"
echo "=========================================="
echo ""
echo "📊 Cluster Status:"
kubectl get pods -A | grep -E 'NAMESPACE|argocd|cnoe-platform|ingress-nginx'

echo ""
echo "🔗 Access URLs (using port-forward):"
echo "   Backstage: kubectl port-forward -n backstage svc/backstage 7007:7007"
echo "             Then open: http://localhost:7007"
echo ""
echo "   Portal:    kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8081:8081"
echo "             Then open: http://localhost:8081"
echo ""
echo "   API:       kubectl port-forward -n cnoe-platform svc/cnoe-platform-services 8080:8080"
echo "             Then open: http://localhost:8080/api/info"
echo ""
echo "   ArgoCD:    kubectl port-forward svc/argocd-server -n argocd 8443:443"
echo "             Then open: https://localhost:8443"
echo "             Username: admin"
echo "             Password: $ARGOCD_PASSWORD"
echo ""
echo "💰 Estimated Monthly Cost: ~$40-50 USD"
echo ""
echo "📖 Next Steps:"
echo "   1. Access Backstage and configure integrations"
echo "   2. Create Azure landing zones using templates"
echo "   3. Configure Azure DevOps/GitHub service connections"
echo "   4. Register existing services in catalog"
echo ""
echo "📚 Documentation:"
echo "   - Setup Guide: docs/SETUP_GUIDE.md"
echo "   - Quick Start: docs/QUICKSTART.md"
echo ""
