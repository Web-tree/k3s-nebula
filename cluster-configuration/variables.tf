# Cluster Configuration Variables

# AWS region for SSM Parameter Store
variable "aws_region" {
  description = "AWS region for SSM parameter store"
  type        = string
  default     = "eu-central-1"
}

# =============================================================================
# ArgoCD Bootstrap Variables
# Feature: 002-argocd-bootstrap
# =============================================================================

variable "argocd_enabled" {
  type        = bool
  default     = true
  description = "Enable ArgoCD installation"
}

variable "argocd_namespace" {
  type        = string
  default     = "argocd"
  description = "Kubernetes namespace for ArgoCD"
}

variable "argocd_chart_version" {
  type        = string
  default     = "9.1.3"
  description = "ArgoCD Helm chart version (maps to ArgoCD v3.2.0)"
}

variable "argocd_domain" {
  type        = string
  description = "Domain for ArgoCD UI"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]+[a-z0-9]$", var.argocd_domain))
    error_message = "argocd_domain must be a valid domain name"
  }
}

variable "keycloak_url" {
  type        = string
  description = "Keycloak server URL"

  validation {
    condition     = can(regex("^https://", var.keycloak_url))
    error_message = "keycloak_url must use HTTPS"
  }
}

variable "keycloak_realm" {
  type        = string
  description = "Keycloak realm name"

  validation {
    condition     = var.keycloak_realm != "master" && var.keycloak_realm != ""
    error_message = "keycloak_realm must not be empty and should typically not be 'master'."
  }
}

variable "git_repo_url" {
  type        = string
  description = "Git repository URL for GitOps (SSH format)"

  validation {
    condition     = can(regex("^git@", var.git_repo_url))
    error_message = "git_repo_url must be SSH format (git@...)"
  }
}

variable "ssm_deploy_key_path" {
  type        = string
  description = "AWS SSM parameter path to SSH deploy key"

  validation {
    condition     = can(regex("^/", var.ssm_deploy_key_path))
    error_message = "ssm_deploy_key_path must start with /."
  }
}

variable "ssm_keycloak_admin_path" {
  type        = string
  description = "AWS SSM parameter path to Keycloak admin credentials (JSON with username/password)"

  validation {
    condition     = can(regex("^/", var.ssm_keycloak_admin_path))
    error_message = "ssm_keycloak_admin_path must start with /."
  }
}

variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to kubeconfig file"
}

variable "letsencrypt_email" {
  type        = string
  description = "Email address for Let's Encrypt certificate notifications"
}

# =============================================================================
# Infrastructure State & DNS Variables
# =============================================================================

variable "base_domain" {
  type        = string
  description = "Base domain for the cluster (e.g. example.com)"

  validation {
    condition     = var.base_domain != "" && var.base_domain != "example.com"
    error_message = "base_domain must be set to your actual domain name."
  }
}

variable "infrastructure_state_bucket" {
  type        = string
  description = "S3 bucket name for infrastructure state"

  validation {
    condition     = var.infrastructure_state_bucket != "" && !can(regex("example|placeholder", var.infrastructure_state_bucket))
    error_message = "infrastructure_state_bucket must be a valid S3 bucket name."
  }
}

variable "infrastructure_state_key" {
  type        = string
  description = "S3 key for infrastructure state"

  validation {
    condition     = var.infrastructure_state_key != ""
    error_message = "infrastructure_state_key must not be empty."
  }
}

variable "infrastructure_state_region" {
  type        = string
  description = "AWS region for infrastructure state bucket"
  default     = "eu-central-1"
}

variable "git_repo_secret_name" {
  type        = string
  description = "Name for the ArgoCD Git repository secret"
  default     = "infrastructure-repo"
}

variable "longhorn_subdomain" {
  type        = string
  default     = "longhorn"
  description = "Subdomain for Longhorn UI (e.g. 'longhorn' -> longhorn.example.com)"
}
