// чарт envoy gateway. version запінений навмисно - Backend CRD (gateway.envoyproxy.io/v1alpha1)
// потребує мінімальну версію чарта, це функціональна залежність, а не питання стилю
resource "helm_release" "envoy_gw" {
  name             = "gateway-helm"
  chart            = "gateway-helm"
  repository       = "oci://docker.io/envoyproxy"
  version          = "v1.9.0"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.envoy_gw.metadata[0].name

  set = [
    {
      name  = "config.envoyGateway.extensionApis.enableBackend"
      value = "true"
    }
  ]
}

// NLB замість дефолтного Classic ELB - дешевше і продуктивніше для L4-passthrough, яким тут займається envoy
resource "kubectl_manifest" "envoy_proxy" {
  yaml_body = file("${path.module}/manifests/envoy/envoy-proxy.yml")

  depends_on = [helm_release.envoy_gw]
}

resource "kubectl_manifest" "gateway_class" {
  yaml_body = file("${path.module}/manifests/envoy/gateway-class.yml")

  depends_on = [helm_release.envoy_gw, kubectl_manifest.envoy_proxy]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = file("${path.module}/manifests/envoy/gateway.yml")

  depends_on = [kubectl_manifest.gateway_class]
}
