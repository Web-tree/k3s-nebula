resource "kubernetes_manifest" "traefik_config" {
  manifest = {
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = "kube-system"
    }
    spec = {
      valuesContent = yamlencode({
        additionalArguments = [
          "--certificatesresolvers.letsencrypt.acme.email=${var.letsencrypt_email}",
          "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json",
          "--certificatesresolvers.letsencrypt.acme.caserver=https://acme-v02.api.letsencrypt.org/directory",
          "--certificatesresolvers.letsencrypt.acme.tlschallenge=true",
          "--log.level=DEBUG",
        ]
      })
    }
  }
}
