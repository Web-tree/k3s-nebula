apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  chart: cert-manager
  repo: oci://quay.io/jetstack/charts
  targetNamespace: cert-manager
  version: ${cert_manager_version}
  valuesContent: |-
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





