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
