# cert-manager Helm Values Template
# Chart: cert-manager v1.19.1

# Install CRDs automatically
crds:
  enabled: true

# Resource limits for cert-manager components
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi

