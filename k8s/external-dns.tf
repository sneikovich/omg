resource "helm_release" "external_dns" {
  name             = "external-dns"
  chart            = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.external_dns.metadata[0].name

  set = {
    "provider"              = "aws"
    "sources[0]"            = "gateway-httproute"
    "txtOwnerId"            = "teno-wa-01"
    "domainFilters[0]"      = var.domain_name
    "serviceAccount.name"   = "external-dns" # має збігатись з service_account в eks/external-dns-pod-identity.tf
    "serviceAccount.create" = "true"
  }

  depends_on = [helm_release.envoy_gw]
}
