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
