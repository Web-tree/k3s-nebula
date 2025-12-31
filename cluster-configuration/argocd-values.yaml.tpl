# ArgoCD Helm Values Template
# Chart: argo-cd 9.1.x (ArgoCD v3.2.0)

global:
  domain: ${domain}

# Server configuration
server:
  # Insecure mode - Traefik handles TLS termination
  extraArgs:
    - --insecure

  # Ingress disabled - we create it manually with correct port (80) for --insecure mode
  # The Helm chart defaults to port 443 when tls: true, but we need 80 when using --insecure
  ingress:
    enabled: false
  ingressGrpc:
    enabled: false


  # Resource limits per research.md
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi

# Controller configuration
controller:
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 1000m
      memory: 1Gi

# Repo server configuration
repoServer:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

# Redis configuration
redis:
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 250m
      memory: 128Mi

# ApplicationSet controller configuration
applicationSet:
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 250m
      memory: 128Mi

# Notifications controller configuration
notifications:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 100m
      memory: 128Mi

# ArgoCD ConfigMap settings
configs:
  cm:
    # ArgoCD external URL (required for OIDC redirects)
    url: https://${domain}
    
    # OIDC configuration for Keycloak
    oidc.config: |
      name: Keycloak
      issuer: ${keycloak_url}/realms/${keycloak_realm}
      clientID: argocd
      %{ if keycloak_client_secret != "" }clientSecret: $oidc.keycloak.clientSecret%{ endif }
      enablePKCEAuthentication: true
      requestedScopes:
        - openid
        - profile
        - email
        - groups

  # RBAC configuration - ArgoCD 3.x compatible
  rbac:
    policy.csv: |
      # ArgoCD 3.x requires explicit logs permission
      p, role:admin, logs, get, *, allow
      p, role:admin, applications, *, */*, allow
      p, role:admin, applications/*, *, */*, allow
      p, role:admin, clusters, get, *, allow
      p, role:admin, repositories, *, *, allow
      p, role:admin, projects, *, *, allow

      g, ArgoCD-Admins, role:admin
      g, ArgoCD-Developers, role:readonly
    policy.default: role:readonly
    scopes: "[groups]"

  # Secret configuration - OIDC client secret for Keycloak
  secret:
    extra:
      %{ if keycloak_client_secret != "" }oidc.keycloak.clientSecret: ${keycloak_client_secret}%{ endif }
