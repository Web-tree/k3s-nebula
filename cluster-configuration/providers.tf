terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.5"
    }
  }
}

# AWS provider for SSM Parameter Store access
provider "aws" {
  region = var.aws_region
}

# Kubernetes provider - uses cluster infrastructure kubeconfig
provider "kubernetes" {
  config_path = var.kubeconfig_path
  insecure    = true # Skip TLS verification for self-signed cert
}

# Helm provider - uses cluster infrastructure kubeconfig
provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
    insecure    = true # Skip TLS verification for self-signed cert
  }
}

# Keycloak provider - configured via SSM credentials
# Note: keycloak_admin data source is defined in argocd.tf
provider "keycloak" {
  client_id = "admin-cli"
  username  = var.argocd_enabled ? jsondecode(data.aws_ssm_parameter.keycloak_admin[0].value)["username"] : ""
  password  = var.argocd_enabled ? jsondecode(data.aws_ssm_parameter.keycloak_admin[0].value)["password"] : ""
  url       = var.keycloak_url
  realm     = var.keycloak_realm
}
