# Cluster Configuration

Terraform configuration for deploying Kubernetes resources to the k3s cluster.

## Overview

This project configures the **cluster resources**:

- **ArgoCD**: GitOps continuous deployment
- **Keycloak OIDC Client**: Single sign-on integration
- **Traefik IngressRoutes**: HTTP/HTTPS routing for ArgoCD
- **Kubernetes Secrets**: Git repository access and OIDC credentials

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI (configured with credentials)
- **Cluster infrastructure deployed** (see `../cluster-infrastructure`)
- **Kubeconfig configured** (`~/.kube/config` pointing to the cluster)
- Keycloak instance running and accessible

## Quick Start

### 1. Ensure Infrastructure is Deployed

```bash
cd ../cluster-infrastructure
terraform output cluster_endpoint
# Should return: https://<LOAD_BALANCER_IP>:6443
```

### 2. Configure kubectl

```bash
cd ../scripts
./retrieve-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes
# Should show all cluster nodes as Ready
```

### 3. Configure Variables

Edit `terraform.tfvars`:

```hcl
argocd_domain = "argocd.yourdomain.com"
keycloak_url  = "https://kc.yourdomain.com"
```

### 4. Store Secrets in AWS SSM

```bash
# SSH deploy key for Git repository
aws ssm put-parameter \
  --region eu-central-1 \
  --name "/argocd/deploy-key" \
  --type "SecureString" \
  --value "$(cat ~/.ssh/deploy-key)"

# Keycloak admin credentials (JSON format)
aws ssm put-parameter \
  --region eu-central-1 \
  --name "/keycloak/admin-credentials" \
  --type "SecureString" \
  --value '{"username":"admin","password":"your-password"}'
```

### 5. Deploy Configuration

```bash
terraform init
terraform plan
terraform apply
```

### 6. Access ArgoCD

```bash
# Get ArgoCD URL
terraform output argocd_server_url

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Configuration Details

### Remote State

This project reads outputs from the infrastructure project via Terraform remote state:

```hcl
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "tf-state-bucket-084375558068"
    key    = "k3s-nebula/k8s/infrastructure/terraform.tfstate"
    region = "eu-central-1"
  }
}
```

Available infrastructure outputs:
- `cluster_endpoint`: Kubernetes API endpoint
- `load_balancer_ip`: Public IP for ingress
- `cluster_name`: Cluster identifier
- `environment`: Environment tag

### ArgoCD Setup

ArgoCD is configured with:
- Keycloak OIDC authentication
- Git repository access via SSH deploy key
- Traefik IngressRoutes for UI and gRPC
- Let's Encrypt TLS certificates

## Verification

### Check ArgoCD Pods

```bash
kubectl get pods -n argocd
# All pods should be Running
```

### Test ArgoCD UI

```bash
# Get URL
terraform output argocd_server_url

# Open in browser and login with Keycloak
```

### Check Keycloak Integration

```bash
# Verify OIDC client exists
# Login to Keycloak admin console
# Navigate to: Clients -> argocd
```

## Troubleshooting

### ArgoCD pods not starting

```bash
kubectl describe pod -n argocd <pod-name>
kubectl logs -n argocd <pod-name>
```

### Keycloak connection issues

```bash
# Check Keycloak provider configuration
terraform console
> data.aws_ssm_parameter.keycloak_admin[0].value
```

### IngressRoute not working

```bash
# Check Traefik is running
kubectl get pods -n kube-system | grep traefik

# Check IngressRoute
kubectl get ingressroute -n argocd
kubectl describe ingressroute argocd-server -n argocd
```

## Deployment Order

> [!IMPORTANT]
> This configuration **must** be deployed after the infrastructure project:
>
> 1. Deploy infrastructure: `cd ../cluster-infrastructure && terraform apply`
> 2. Retrieve kubeconfig: `cd ../scripts && ./retrieve-kubeconfig.sh`
> 3. Verify cluster: `kubectl get nodes`
> 4. Deploy configuration: `cd ../cluster-configuration && terraform apply`

## Updating Configuration

To update ArgoCD or other resources:

```bash
# Modify terraform.tfvars or *.tf files
terraform plan
terraform apply
```

## Destroying Configuration

```bash
# Remove ArgoCD and all Kubernetes resources
terraform destroy

# Note: This does NOT destroy the underlying cluster infrastructure
```
