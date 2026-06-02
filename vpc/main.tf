module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  # public_subnet_tags = {
  #   "kubernetes.io/role/elb" = "1"
  #   "kubernetes.io/cluster/main" = "shared"
  # }

  # private_subnet_tags = {
  #   "kubernetes.io/role/internal-elb" = "1"
  #   "kubernetes.io/cluster/main"      = "shared"
  # }

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
