variable "instance_types" {
  type = list(string)
  # t3.small (~11 подів/ноду, 2 GiB) вичерпався ще до моніторингу: osm-app + envoy-gw +
  # cert-manager + external-dns + системні поди займали ~21 із ~22 слотів.
  # t3.medium (~17 подів/ноду, 4 GiB) дає запас під Loki/Mimir/Grafana/otel-collector
  default = ["t3.medium"]
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
