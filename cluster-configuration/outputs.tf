# Outputs from cluster configuration

# Infrastructure outputs (from remote state)
output "cluster_endpoint" {
  value       = local.cluster_endpoint
  description = "Kubernetes API endpoint (from infrastructure)"
}

output "cluster_name" {
  value       = local.cluster_name
  description = "Cluster name (from infrastructure)"
}

# Note: ArgoCD outputs are defined in argocd.tf

