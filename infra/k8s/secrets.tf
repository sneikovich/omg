# за прикладом cloudflare_api_token: креди йдуть у k8s Secret, а не в plain env на Deployment
resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
  }

  data = {
    user         = "history"
    password     = var.postgres_password
    db           = "history"
    database_url = "postgres://history:${var.postgres_password}@postgres:5432/history"
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq-credentials"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
  }

  data = {
    user     = "app"
    password = var.rabbitmq_password
    amqp_url = "amqp://app:${var.rabbitmq_password}@rabbitmq:5672/%2f"
  }

  type = "Opaque"
}

# пароль адміна Grafana чарт читає через admin.existingSecret, а не з values (щоб не світити в plan-виводі)
resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  }

  type = "Opaque"
}

# otel-gateway збирає метрики Postgres, а секрети між namespace не діляться - тримаємо копію
# в monitoring. Значення ті самі, що в kubernetes_secret_v1.postgres, тож "дрейфу" немає
resource "kubernetes_secret_v1" "postgres_monitoring" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    user     = kubernetes_secret_v1.postgres.data["user"]
    password = kubernetes_secret_v1.postgres.data["password"]
  }

  type = "Opaque"
}
