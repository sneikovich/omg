variable "k8s_path" {
  type    = string
  default = "~/.kube/config"
}

variable "domain_name" {
  type    = string
  default = "zmeypavel.com" # має збігатись з eks/'s var.domain_name
}

variable "acme_email" {
  type = string
}

variable "acme_server" {
  type    = string
  default = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "overpass_endpoint" {
  type    = string
  default = "https://overpass-api.de/api/interpreter"
}

variable "fetcher_image_tag" {
  type    = string
  default = "latest"
}

variable "history_image_tag" {
  type    = string
  default = "latest"
}

# дефолти збігаються з osm-app/compose.yaml, щоб поведінка не "дрейфувала" між compose і k8s
variable "postgres_password" {
  type      = string
  sensitive = true
  default   = "history"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
  default   = "app"
}

# Grafana не публікується назовні (лише kubectl port-forward), тож дефолт як у postgres/rabbitmq;
# перед будь-яким публічним доступом - змінити через terraform.tfvars
variable "grafana_admin_password" {
  type      = string
  sensitive = true
  default   = "admin"
}

# скільки тримати метрики (Mimir) та логи (Loki); формат Go-duration (h), бо так вимагають обидва
variable "monitoring_retention" {
  type    = string
  default = "168h"
}

# страховка на рівні S3: об'єкти старші за N днів видаляє lifecycle, навіть якщо compactor Loki/Mimir
# не відпрацював ретенцію; має бути більшим за monitoring_retention
variable "monitoring_s3_expiration_days" {
  type    = number
  default = 14
}
