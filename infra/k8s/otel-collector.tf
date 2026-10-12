# два колектори з contrib-образом (filelog/postgresql/redis/k8s_cluster є лише там):
#  - otel-agent   (DaemonSet): логи всіх подів + метрики kubelet з кожної ноди
#  - otel-gateway (Deployment x1): стан кластера, redis, postgres, scrape /metrics (envoy, rabbitmq, rust-сервіси)
# логи йдуть у Loki (OTLP), метрики - в Mimir (remote write). Values - monitoring/otel-*-values.yml.tftpl
locals {
  loki_otlp_endpoint  = "http://loki.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:3100/otlp"
  mimir_push_endpoint = "http://mimir.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:8080/api/v1/push"
}

resource "helm_release" "otel_agent" {
  name             = "otel-agent"
  chart            = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  version          = "0.175.1"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name

  # не блокувати apply очікуванням готовності подів (див. loki.tf)
  wait    = false
  timeout = 600

  values = [
    templatefile("${path.module}/monitoring/otel-agent-values.yml.tftpl", {
      loki_endpoint  = local.loki_otlp_endpoint
      mimir_endpoint = local.mimir_push_endpoint
    })
  ]

  depends_on = [helm_release.loki, kubernetes_service_v1.mimir]
}

resource "helm_release" "otel_gateway" {
  name             = "otel-gateway"
  chart            = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  version          = "0.175.1"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name

  wait    = false
  timeout = 600

  values = [
    templatefile("${path.module}/monitoring/otel-gateway-values.yml.tftpl", {
      mimir_endpoint  = local.mimir_push_endpoint
      postgres_secret = kubernetes_secret_v1.postgres_monitoring.metadata[0].name
    })
  ]

  # envoy_gw - щоб prometheus receiver мав що скрейпити в ns envoy-gw (інакше job просто порожній до появи подів)
  depends_on = [helm_release.envoy_gw, kubernetes_service_v1.mimir, kubernetes_secret_v1.postgres_monitoring]
}
