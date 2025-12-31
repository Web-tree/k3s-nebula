# Remote state data source to read infrastructure outputs

data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    bucket = var.infrastructure_state_bucket
    key    = var.infrastructure_state_key
    region = var.infrastructure_state_region
  }
}

# Route53 zone for base domain
data "aws_route53_zone" "this" {
  count = var.argocd_enabled ? 1 : 0
  name  = var.base_domain
}

# Convenience locals to reference infrastructure outputs
locals {
  cluster_endpoint = data.terraform_remote_state.infrastructure.outputs.cluster_endpoint
  load_balancer_ip = data.terraform_remote_state.infrastructure.outputs.load_balancer_ip
  cluster_name     = data.terraform_remote_state.infrastructure.outputs.cluster_name
  environment      = data.terraform_remote_state.infrastructure.outputs.environment
}
