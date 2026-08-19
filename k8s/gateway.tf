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
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "envoy-gateway-class"
    }
    spec = {
      controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
    }
  })

  depends_on = [helm_release.envoy_gw]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "main-gateway"
      namespace = kubernetes_namespace_v1.envoy_gw.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
      }
    }
    spec = {
      gatewayClassName = "envoy-gateway-class"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        },
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          tls = {
            mode = "Terminate"
            certificateRefs = [{
              name      = "main-gateway-tls"
              namespace = kubernetes_namespace_v1.envoy_gw.metadata[0].name
            }]
          }
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        },
      ]
    }
  })

  depends_on = [kubectl_manifest.gateway_class]
}
