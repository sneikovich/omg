resource "kubernetes_deployment_v1" "history" {
  metadata {
    name      = "history"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
    labels    = { app = "history" }
  }

  spec {
    # stateless (sqlx-міграції йдуть під advisory lock, безпечно для конкурентних реплік)
    replicas = 2

    selector {
      match_labels = { app = "history" }
    }

    template {
      metadata {
        labels = { app = "history" }
      }

      spec {
        container {
          name  = "history"
          image = "${aws_ecr_repository.history.repository_url}:${var.history_image_tag}"

          port {
            container_port = 8081
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres.metadata[0].name
                key  = "database_url"
              }
            }
          }

          env {
            name = "RABBITMQ_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.rabbitmq.metadata[0].name
                key  = "amqp_url"
              }
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8081
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8081
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "history" {
  metadata {
    name      = "history"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
  }

  spec {
    selector = { app = "history" }

    port {
      port        = 8081
      target_port = 8081
    }
  }
}
