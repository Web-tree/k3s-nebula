# Cluster Infrastructure

Terraform configuration for provisioning the HA k3s Kubernetes cluster on Hetzner Cloud.

## Overview

This project creates the **infrastructure** for the cluster:

- **2+ control plane nodes** (also running workloads)
- **1 HAProxy load balancer** for HA cluster access
- **Private network** for inter-node communication
- **IAM credentials** for nodes to access AWS SSM
- **PostgreSQL-backed** state persistence (external)

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI (configured with credentials)
- SSH key pair
- AWS Account with SSM Parameter Store access
- Hetzner Cloud Account with API token
- PostgreSQL Database (managed service recommended)

## Quick Start

### 1. Store Secrets in AWS SSM

```bash
# Hetzner API token
aws ssm put-parameter \
  --region eu-central-1 \
  --name "/hetzner/api-key" \
  --type "SecureString" \
  --value "YOUR_HETZNER_API_TOKEN"

# PostgreSQL connection string
aws ssm put-parameter \
  --region eu-central-1 \
  --name "/k3s/hetzner/postgres/connection-string" \
  --type "SecureString" \
  --value "postgres://user:pass@host:5432/database"
```

### 2. Configure Variables

Edit `terraform.tfvars`:

```hcl
ssh_public_keys = ["ssh-rsa AAAAB3... your-key-here"]
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
# Get outputs
terraform output -json | jq

# SSH to control plane
terraform output -json | jq -r '.control_plane_nodes.value[0].ipv4' | xargs -I {} ssh root@{}

# Check k3s status
ssh root@$(terraform output -json | jq -r '.control_plane_nodes.value[0].ipv4') "systemctl status k3s"
```

## Outputs

Key outputs for the cluster-configuration project:

- **cluster_endpoint**: Kubernetes API endpoint URL
- **load_balancer_ip**: Public IP for ingress and API access
- **cluster_name**: Cluster identifier
- **environment**: Environment tag (prod/staging/dev)
- **kubeconfig_command**: Command to retrieve kubeconfig

## Next Steps

After infrastructure deployment:

1. Retrieve kubeconfig: `cd ../scripts && ./retrieve-kubeconfig.sh`
2. Verify cluster: `kubectl get nodes`
3. Deploy cluster configuration: `cd ../cluster-configuration && terraform apply`

## Architecture

```
┌──────────────┐
│ Load Balancer│ :6443
└──────┬───────┘
       │
   ┌───┴───┐
   │       │
┌──▼───┐ ┌─▼────┐
│ CP-1 │ │ CP-2 │ (control_plane + worker)
└──┬───┘ └─┬────┘
   │       │
   └───┬───┘
       │
  ┌────▼─────┐
  │PostgreSQL│ (external)
  └──────────┘
```

## Troubleshooting

### Nodes not joining cluster

```bash
NODE_IP=$(terraform output -json | jq -r '.control_plane_nodes.value[0].ipv4')
ssh root@$NODE_IP "systemctl status k3s"
ssh root@$NODE_IP "journalctl -u k3s -n 100"
```

### API not responding

```bash
LB_IP=$(terraform output -json | jq -r '.load_balancer_ip.value')
curl -k https://$LB_IP:6443/healthz
ssh root@$LB_IP "systemctl status haproxy"
```

### Cloud-init debugging

```bash
NODE_IP=$(terraform output -json | jq -r '.control_plane_nodes.value[0].ipv4')
ssh root@$NODE_IP "tail -100 /var/log/cloud-init-output.log"
```

## Cost Estimation

Minimal HA setup (2x cx22 + 1x cx22):
- **Monthly**: ~€17.59 (~$19 USD)
- Plus external PostgreSQL costs
