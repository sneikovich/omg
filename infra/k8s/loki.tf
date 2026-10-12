# Loki у режимі SingleBinary: розподілений режим не влізе в кластер (див. mimir.tf).
# Сховище - S3 через Pod Identity (monitoring-storage.tf), values - monitoring/loki-values.yml.tftpl
resource "helm_release" "loki" {
  name             = "loki"
  chart            = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  version          = "7.3.0"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name

  # як і для app-деплойментів: не блокувати apply очікуванням готовності подів -
  # довгий apply переживає короткоживучі AWS/EKS-токени (див. CLAUDE.md)
  wait    = false
  timeout = 600

  values = [
    templatefile("${path.module}/monitoring/loki-values.yml.tftpl", {
      bucket    = aws_s3_bucket.monitoring["loki"].id
      region    = data.aws_region.current.region
      retention = var.monitoring_retention
    })
  ]

  # без Pod Identity-асоціації под стартує, але не зможе писати в S3
  depends_on = [aws_eks_pod_identity_association.monitoring]
}
