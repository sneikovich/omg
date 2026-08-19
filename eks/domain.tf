variable "domain_name" {
  type    = string
  default = "bubbub.com"
}

# хостована зона вже існує, тут лише lookup
data "aws_route53_zone" "this" {
  name = var.domain_name
}
