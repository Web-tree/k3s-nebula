# =============================================================================
# Longhorn Distributed Storage Configuration
# =============================================================================
# Manages DNS record for Longhorn storage management UI
# Longhorn is deployed via ArgoCD (GitOps) from k8s/apps/longhorn/
# =============================================================================

# Route53 DNS Record for Longhorn UI
resource "aws_route53_record" "longhorn" {
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.longhorn_subdomain
  type    = "A"
  ttl     = 300
  records = [local.load_balancer_ip]
}

# =============================================================================
# Longhorn Node Configuration
# =============================================================================
# Note: Longhorn volumes are created in cluster-infrastructure/servers.tf
# and mounted to /var/lib/longhorn via cloud-init during node provisioning.
# Longhorn will automatically discover disks at this path when nodes join the cluster.

# =============================================================================
# Outputs
# =============================================================================

output "longhorn_ui_url" {
  value       = var.argocd_enabled ? "https://${var.longhorn_subdomain}.${var.base_domain}" : null
  description = "Longhorn storage management UI URL"
}
