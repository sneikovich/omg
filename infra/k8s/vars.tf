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
