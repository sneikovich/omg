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
