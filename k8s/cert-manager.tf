resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  chart            = "cert-manager"
  repository       = "oci://quay.io/jetstack/charts/"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.cert_manager.metadata[0].name

  set = { "crds.enabled" = "true" }

  values = [
    yamlencode({
      config = {
        gatewayAPI = {
          enabled = true
        }
      }
    })
  ]

  # cert-manager визначає підтримку Gateway API лише при старті пода,
  # тож CRD-и мають бути встановлені envoy gateway чартом до цього моменту
  depends_on = [helm_release.envoy_gw]
}

resource "kubectl_manifest" "letsencrypt_staging" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = var.acme_server
        email  = var.acme_email
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [{
          http01 = {
            gatewayHTTPRoute = {
              parentRefs = [{
                name      = "main-gateway"
                namespace = kubernetes_namespace_v1.envoy_gw.metadata[0].name
                kind      = "Gateway"
              }]
            }
          }
        }]
      }
    }
  })

  depends_on = [helm_release.cert_manager, kubectl_manifest.gateway]
}
