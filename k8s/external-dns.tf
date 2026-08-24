# токен зберігаємо в k8s secret, а не напряму в helm values, щоб не світити його в tfstate plan-виводі/логах
resource "kubernetes_secret_v1" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = kubernetes_namespace_v1.external_dns.metadata[0].name
  }

  data = {
    apiKey = var.cloudflare_api_token
  }

  type = "Opaque"
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  chart            = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.external_dns.metadata[0].name

  set = [
    { name = "provider", value = "cloudflare" },
    { name = "sources[0]", value = "gateway-httproute" },
    { name = "txtOwnerId", value = "bubba-project" },
    { name = "domainFilters[0]", value = var.domain_name },
    { name = "serviceAccount.name", value = "external-dns" },
    { name = "serviceAccount.create", value = "true" },
  ]

  values = [
    yamlencode({
      env = [{
        name = "CF_API_TOKEN"
        valueFrom = {
          secretKeyRef = {
            name = kubernetes_secret_v1.cloudflare_api_token.metadata[0].name
            key  = "apiKey"
          }
        }
      }]
    })
  ]

  depends_on = [helm_release.envoy_gw, kubernetes_secret_v1.cloudflare_api_token]
}
