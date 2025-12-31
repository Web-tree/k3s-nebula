# =============================================================================
# Data Sources - AWS SSM Parameters
# =============================================================================

# SSH deploy key for Git repository access
data "aws_ssm_parameter" "argocd_deploy_key" {
  count           = var.argocd_enabled ? 1 : 0
  name            = var.ssm_deploy_key_path
  with_decryption = true
}

# Keycloak admin credentials (JSON: {"username": "...", "password": "..."})
data "aws_ssm_parameter" "keycloak_admin" {
  count           = var.argocd_enabled ? 1 : 0
  name            = var.ssm_keycloak_admin_path
  with_decryption = true
}

# =============================================================================
# Keycloak Realm Data Source
# =============================================================================

data "keycloak_realm" "this" {
  count = var.argocd_enabled ? 1 : 0
  realm = var.keycloak_realm
}

# =============================================================================
# Keycloak OIDC Client for ArgoCD
# =============================================================================

resource "keycloak_openid_client" "argocd" {
  count                        = var.argocd_enabled ? 1 : 0
  realm_id                     = data.keycloak_realm.this[0].id
  client_id                    = "argocd"
  name                         = "ArgoCD"
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false

  root_url = "https://${var.argocd_domain}"
  valid_redirect_uris = [
    "https://${var.argocd_domain}/auth/callback",
    "https://${var.argocd_domain}/auth/callback/",
    "http://localhost:8085/auth/callback" # for cli login
  ]
  valid_post_logout_redirect_uris = ["https://${var.argocd_domain}/applications"]
  web_origins                     = ["https://${var.argocd_domain}"]

  pkce_code_challenge_method = "S256"
}

# =============================================================================
# Keycloak Groups Scope and Mapper
# =============================================================================

# Client scope for groups claim
resource "keycloak_openid_client_scope" "groups" {
  count                  = var.argocd_enabled ? 1 : 0
  realm_id               = data.keycloak_realm.this[0].id
  name                   = "groups"
  description            = "Group membership for ArgoCD RBAC"
  include_in_token_scope = true
}

# Group membership mapper
resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  count           = var.argocd_enabled ? 1 : 0
  realm_id        = data.keycloak_realm.this[0].id
  client_scope_id = keycloak_openid_client_scope.groups[0].id
  name            = "groups"
  claim_name      = "groups"
  full_path       = false
}

# Assign groups scope to ArgoCD client
resource "keycloak_openid_client_default_scopes" "argocd" {
  count     = var.argocd_enabled ? 1 : 0
  realm_id  = data.keycloak_realm.this[0].id
  client_id = keycloak_openid_client.argocd[0].id

  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.groups[0].name,
  ]
}

# =============================================================================
# ArgoCD Helm Release
# =============================================================================

resource "helm_release" "argocd" {
  count            = var.argocd_enabled ? 1 : 0
  name             = "argocd"
  namespace        = var.argocd_namespace
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  values = [templatefile("${path.module}/argocd-values.yaml.tpl", {
    domain                 = var.argocd_domain
    keycloak_url           = var.keycloak_url
    keycloak_realm         = var.keycloak_realm
    keycloak_client_secret = try(keycloak_openid_client.argocd[0].client_secret, "")
  })]

  wait    = true
  timeout = 600

  depends_on = [
    keycloak_openid_client.argocd,
  ]
}

# =============================================================================
# Kubernetes Secrets for ArgoCD
# =============================================================================

# Git repository secret with SSH deploy key
resource "kubernetes_secret" "argocd_repo" {
  count = var.argocd_enabled ? 1 : 0

  metadata {
    name      = var.git_repo_secret_name
    namespace = var.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type          = "git"
    url           = var.git_repo_url
    sshPrivateKey = data.aws_ssm_parameter.argocd_deploy_key[0].value
  }

  depends_on = [helm_release.argocd]
}

# =============================================================================
# Kubernetes Ingress for ArgoCD (Standard Ingress with correct port)
# =============================================================================
# We create ingress manually because the Helm chart defaults to port 443 when
# tls: true, but with --insecure we need port 80 (HTTP backend)

resource "kubernetes_ingress_v1" "argocd_server" {
  count = var.argocd_enabled ? 1 : 0

  metadata {
    name      = "argocd-server"
    namespace = var.argocd_namespace
    annotations = {
      "traefik.ingress.kubernetes.io/router.tls.certresolver" = "letsencrypt"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = var.argocd_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = [var.argocd_domain]
      secret_name = "argocd-server-tls"
    }
  }

  depends_on = [
    helm_release.argocd,
  ]
}

resource "kubernetes_ingress_v1" "argocd_server_grpc" {
  count = var.argocd_enabled ? 1 : 0

  metadata {
    name      = "argocd-server-grpc"
    namespace = var.argocd_namespace
    annotations = {
      "traefik.ingress.kubernetes.io/router.tls.certresolver" = "letsencrypt"
    }
  }

  spec {
    ingress_class_name = "traefik"

    rule {
      host = "grpc.${var.argocd_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    tls {
      hosts       = ["grpc.${var.argocd_domain}"]
      secret_name = "argocd-server-grpc-tls"
    }
  }

  depends_on = [
    helm_release.argocd,
  ]
}

# =============================================================================
# Route53 DNS Record for ArgoCD
# =============================================================================

resource "aws_route53_record" "argocd" {
  count   = var.argocd_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = "argocd"
  type    = "A"
  ttl     = 300
  records = [local.load_balancer_ip]
}

# =============================================================================
# Outputs
# =============================================================================

output "argocd_server_url" {
  value       = var.argocd_enabled ? "https://${var.argocd_domain}" : null
  description = "ArgoCD UI URL"
}

output "argocd_namespace" {
  value       = var.argocd_enabled ? var.argocd_namespace : null
  description = "Namespace where ArgoCD is deployed"
}

output "argocd_initial_admin_secret" {
  value       = var.argocd_enabled ? "argocd-initial-admin-secret" : null
  description = "Secret name containing initial admin password"
}
