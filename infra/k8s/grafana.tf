# Grafana не публікується назовні: доступ лише через kubectl port-forward -n monitoring svc/grafana 3000:80
# (HTTPS-listener main-gateway не має hostname, тож TLS для grafana.<domain> треба розбирати окремо -
# публічний доступ свідомо відкладено)
resource "helm_release" "grafana" {
  name  = "grafana"
  chart = "grafana"
  # чарт grafana/grafana у grafana/helm-charts позначено deprecated - актуальний у grafana-community
  repository       = "https://grafana-community.github.io/helm-charts"
  version          = "13.5.0"
  create_namespace = false
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name

  # не блокувати apply очікуванням готовності подів (див. loki.tf)
  wait    = false
  timeout = 600

  values = [
    templatefile("${path.module}/monitoring/grafana-values.yml.tftpl", {
      admin_secret = kubernetes_secret_v1.grafana_admin.metadata[0].name
      namespace    = kubernetes_namespace_v1.monitoring.metadata[0].name
      mimir_url    = "http://mimir.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:8080/prometheus"
      loki_url     = "http://loki.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:3100"
    })
  ]

  depends_on = [helm_release.loki, kubernetes_service_v1.mimir]
}

# кожен JSON з monitoring/dashboards/ - окремий ConfigMap (ліміт ConfigMap ~1 MiB, дашборди бувають великі);
# sidecar Grafana підхоплює їх за міткою. Щоб додати дашборд - просто кинути файл у каталог
resource "kubernetes_config_map_v1" "grafana_dashboard" {
  for_each = fileset("${path.module}/monitoring/dashboards", "*.json")

  metadata {
    # ім'я ConfigMap - DNS-1123: нижній регістр, без підкреслень/крапок
    name      = "dashboard-${replace(lower(trimsuffix(each.value, ".json")), "/[^a-z0-9-]/", "-")}"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }

  data = {
    (each.value) = file("${path.module}/monitoring/dashboards/${each.value}")
  }
}
