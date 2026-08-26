# демонстрація path-based роутингу: /kube01/ - реальний контент з s3 (kube01/index.html),
# /kubeXX/ (будь-які 2 цифри) - DirectResponse-помилка. Exact-матч має вищий пріоритет за
# RegularExpression в Gateway API, тож /kube01/ коректно перехоплюється раніше за regex-фільтр нижче.

resource "kubectl_manifest" "kube_unknown_response_filter" {
  yaml_body = file("${path.module}/manifests/routing-demo/kube-unknown-filter.yml")

  depends_on = [helm_release.envoy_gw]
}

resource "kubectl_manifest" "kube_routing_demo" {
  yaml_body = templatefile("${path.module}/manifests/routing-demo/http-route.yml", {
    domain_name             = var.domain_name
    bucket_website_hostname = "${aws_s3_bucket.site.id}.s3-website.eu-central-1.amazonaws.com"
  })

  depends_on = [
    aws_s3_object.kube01_index,
    kubectl_manifest.site_backend,
    kubectl_manifest.kube_unknown_response_filter,
    kubectl_manifest.gateway,
  ]
}
