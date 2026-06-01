data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "teno-wa-01"
    key    = "state/vpc/terraform.tfstate"
    region = "eu-central-1"
  }
}


data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "main"
  kubernetes_version = "1.35"

  # Optional
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["${chomp(data.http.my_public_ip.response_body)}/32"]

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled = false
    # node_pools = ["general-purpose"]
  }

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = concat(data.terraform_remote_state.vpc.outputs.private_subnets, data.terraform_remote_state.vpc.outputs.public_subnets)

  eks_managed_node_groups = {
    general = {
      instance_types = var.instance_types
      desired_size   = 1
      min_size       = 1
      max_size       = 5

      subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
