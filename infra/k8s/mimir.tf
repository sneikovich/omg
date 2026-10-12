# Mimir як один под (-target=all), а не чарт mimir-distributed: той розгортає десяток+ подів
# (distributor, ingester x3, store-gateway, memcached, minio...) і не влізе в кластер.
# Нативні ресурси - так само, як postgres.tf/redis.tf. Дані - в S3 (Pod Identity), локально лише WAL/кеш в emptyDir:
# при перезапуску поду втрачаються лише блоки, які ще не встигли відвантажитись (до ~2 год).
locals {
  mimir_config = templatefile("${path.module}/monitoring/mimir.yml.tftpl", {
    bucket    = aws_s3_bucket.monitoring["mimir"].id
    region    = data.aws_region.current.region
    retention = var.monitoring_retention
  })
}

resource "kubernetes_config_map_v1" "mimir" {
  metadata {
    name      = "mimir-config"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    "mimir.yaml" = local.mimir_config
  }
}

# ім'я service account має збігатись з aws_eks_pod_identity_association.monitoring["mimir"]
resource "kubernetes_service_account_v1" "mimir" {
  metadata {
    name      = "mimir"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }
}

resource "kubernetes_deployment_v1" "mimir" {
  metadata {
    name      = "mimir"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels    = { app = "mimir" }
  }

  # не блокувати apply очікуванням готовності поду (та ж причина, що в fetcher.tf)
  wait_for_rollout = false

  spec {
    replicas = 1

    # Recreate, а не RollingUpdate: два Mimir з окремими in-memory кільцями писали б в один бакет
    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = { app = "mimir" }
    }

    template {
      metadata {
        labels = { app = "mimir" }
        # зміна конфіга -> новий хеш -> под перезапускається (Mimir читає конфіг лише на старті)
        annotations = {
          "checksum/config" = sha256(local.mimir_config)
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.mimir.metadata[0].name

        container {
          name  = "mimir"
          image = "grafana/mimir:3.2.2"
          args  = ["-config.file=/etc/mimir/mimir.yaml", "-target=all"]

          port {
            name           = "http"
            container_port = 8080
          }

          port {
            name           = "grpc"
            container_port = 9095
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/mimir"
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = "http"
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 5
          }

          liveness_probe {
            http_get {
              path = "/ready"
              port = "http"
            }
            initial_delay_seconds = 60
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              memory = "1Gi"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.mimir.metadata[0].name
          }
        }

        # emptyDir, та ж причина що в postgres.tf - в кластері немає aws-ebs-csi-driver
        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }

  # без Pod Identity-асоціації под стартує, але не зможе писати в S3
  depends_on = [aws_eks_pod_identity_association.monitoring]
}

resource "kubernetes_service_v1" "mimir" {
  metadata {
    name      = "mimir"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  spec {
    selector = { app = "mimir" }

    # 8080: remote write (/api/v1/push) і Prometheus-сумісний query API (/prometheus) для Grafana
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
