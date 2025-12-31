# Operations Guide: k3s-nebula

This document outlines standard operational procedures for a k3s-nebula cluster.

## Deployment

### Full Stack Deployment

For a complete deployment of both infrastructure and configuration, we recommend using the provided Taskfile:

```bash
task deploy:all
```

This automated task will:
1. Deploy cluster infrastructure
2. Configure RBAC groups
3. Verify cluster health
4. Deploy cluster configuration

### Manual Deployment

#### 1. Deploy Infrastructure

```bash
cd cluster-infrastructure
terraform init
terraform apply
```

#### 2. Retrieve Kubeconfig

```bash
cd ../scripts
./retrieve-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes
```

#### 3. Deploy Configuration

```bash
cd ../cluster-configuration
terraform init
terraform apply
```

## ArgoCD Setup

### Prerequisites

Before deploying ArgoCD, run the secrets setup script:

```bash
./scripts/setup-argocd-secrets.sh
```

### Keycloak Configuration

ArgoCD uses Keycloak for OIDC authentication. Ensure:
1. **Keycloak is accessible** at your configured URL (e.g., `https://auth.example.com`)
2. **The target realm exists**
3. **An admin user exists** with permissions to create clients

#### Keycloak Groups

You need to create groups manually in Keycloak to map to RBAC roles:
1. `ArgoCD-Admins`
2. `ArgoCD-Developers`

## State Management

This project uses **S3** for Terraform state.

- **Infrastructure State**: `s3://<your-bucket>/<path>/infrastructure/terraform.tfstate`
- **Configuration State**: `s3://<your-bucket>/<path>/configuration/terraform.tfstate`

To view outputs:
```bash
cd cluster-infrastructure
terraform output -json | jq
```

## Monitoring

- Check node status: `kubectl get nodes`
- Check pods: `kubectl get pods -A`
- Check Load Balancer: Access HAProxy stats page (if enabled)

---
*This project is maintained by WebTree. For WebTree's specific implementation details, please refer to internal documentation.*
