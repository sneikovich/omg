output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region eu-central-1 --name ${module.eks.cluster_name}"
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "route53_zone_id" {
  value = data.aws_route53_zone.this.zone_id
}
