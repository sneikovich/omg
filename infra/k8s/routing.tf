resource "kubectl_manifest" "osm_app_route" {
  yaml_body = templatefile("${path.module}/manifests/frontend/http-route.yml", {
    domain_name             = var.domain_name
    bucket_website_hostname = "${aws_s3_bucket.frontend.id}.s3-website.eu-central-1.amazonaws.com"
  })

  depends_on = [kubectl_manifest.frontend_backend, kubectl_manifest.gateway, kubernetes_service_v1.fetcher]
}
