// чарт envoy gateway. version запінений навмисно - Backend CRD (gateway.envoyproxy.io/v1alpha1)
// потребує мінімальну версію чарта, це функціональна залежність, а не питання стилю
resource "helm_release" "envoy_gw" {
  name             = "gateway-helm"
  chart            = "gateway-helm"
  repository       = "oci://docker.io/envoyproxy"
  version          = "v1.9.0"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.envoy_gw.metadata[0].name

  set = {
    "config.envoyGateway.extensionApis.enableBackend" = "true"
  }
}

resource "kubectl_manifest" "gateway_class" {
  yaml_body = file("${path.module}/manifests/envoy/gateway-class.yml")

  depends_on = [helm_release.envoy_gw]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = file("${path.module}/manifests/envoy/gateway.yml")

  depends_on = [kubectl_manifest.gateway_class]
}
