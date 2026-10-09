resource "kubernetes_deployment_v1" "fetcher" {
  metadata {
    name      = "fetcher"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
    labels    = { app = "fetcher" }
  }

  # apply не чекає на готовність подів (образу в ECR ще може не бути -
  # інакше apply висить до таймауту і AWS-токен встигає протухнути); готовність
  # перевіряємо окремо через kubectl після push-images.sh
  wait_for_rollout = false

  spec {
    # stateless, горизонтально масштабоване - 2 репліки для старту
    replicas = 2

    selector {
      match_labels = { app = "fetcher" }
    }

    template {
      metadata {
        labels = { app = "fetcher" }
      }

      spec {
        container {
          name  = "fetcher"
          image = "${aws_ecr_repository.fetcher.repository_url}:${var.fetcher_image_tag}"

          port {
            container_port = 8080
          }

          env {
            name  = "OVERPASS_ENDPOINT"
            value = var.overpass_endpoint
          }

          env {
            name  = "OVERPASS_RETRIES"
            value = "3"
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

          # redis без auth, URL без секрету
          env {
            name  = "REDIS_URL"
            value = "redis://redis:6379"
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
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

resource "kubernetes_service_v1" "fetcher" {
  metadata {
    name      = "fetcher"
    namespace = kubernetes_namespace_v1.osm_app.metadata[0].name
  }

  spec {
    selector = { app = "fetcher" }

    port {
      port        = 8080
      target_port = 8080
    }
  }
}
