resource "kubernetes_deployment_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
    labels    = { app = "rabbitmq" }
  }

  # не блокувати apply очікуванням готовності поду (та ж причина, що в fetcher.tf)
  wait_for_rollout = false

  spec {
    replicas = 1

    selector {
      match_labels = { app = "rabbitmq" }
    }

    template {
      metadata {
        labels = { app = "rabbitmq" }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:4-management"

          port {
            container_port = 5672
          }

          port {
            container_port = 15672
          }

          env {
            name = "RABBITMQ_DEFAULT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.rabbitmq.metadata[0].name
                key  = "user"
              }
            }
          }

          env {
            name = "RABBITMQ_DEFAULT_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.rabbitmq.metadata[0].name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/rabbitmq"
          }

          liveness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            # дефолтний timeout_seconds=1 занадто малий - rabbitmq-diagnostics
            # підіймає окремий erlang CLI-процес і на завантаженій ноді не
            # встигає за секунду, kubelet рахує це провалом і вбиває контейнер
            initial_delay_seconds = 20
            period_seconds        = 15
            timeout_seconds       = 10
          }

          readiness_probe {
            exec {
              command = ["rabbitmq-diagnostics", "-q", "ping"]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 10
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        # emptyDir, та ж причина що в postgres.tf - без персистентності для першого заходу
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

# тільки AMQP - management UI (15672) лишається недоступним ззовні Service,
# за потреби дебагу - kubectl port-forward
resource "kubernetes_service_v1" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
  }

  spec {
    selector = { app = "rabbitmq" }

    port {
      name        = "amqp"
      port        = 5672
      target_port = 5672
    }
  }
}
