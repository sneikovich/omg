resource "kubernetes_namespace_v1" "envoy_gw" {
  metadata {
    name = "envoy-gw"
  }
}

resource "kubernetes_namespace_v1" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

// чарти

resource "helm_release" "envoy_gw" {
  name             = "gateway-helm"
  chart            = "gateway-helm"
  repository       = "oci://docker.io/envoyproxy"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.envoy_gw.metadata[0].name
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  chart            = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.external_dns[0].name
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts/"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.cert_manager.metadata[0].name

  set = { "crds.enabled" = "true" }

    values = [
        yamlencode(
            config = {
                enableGatewayAPI = true
            }
        )
    ]
}
