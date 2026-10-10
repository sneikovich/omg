data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = "bubba-project"
    key    = "state/vpc/terraform.tfstate"
    region = "eu-central-1"
  }
}


data "http" "my_public_ip" {
  # ipify не має AAAA-запису - завжди повертає IPv4, незалежно від того, чи
  # клієнт dual-stack/IPv6-only (ifconfig.me віддавав IPv6, що ламало /32 нижче)
  url = "https://api.ipify.org"
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "main"
  kubernetes_version = "1.35"

  # Optional
  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["${chomp(data.http.my_public_ip.response_body)}/32"]

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  compute_config = {
    enabled = false
    # node_pools = ["general-purpose"]
  }

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = concat(data.terraform_remote_state.vpc.outputs.private_subnets, data.terraform_remote_state.vpc.outputs.public_subnets)

  eks_managed_node_groups = {
    general = {
      instance_types = var.instance_types
      desired_size   = 2
      min_size       = 1
      max_size       = 5

      subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnets

      timeouts = {
        create = "10m"
        update = "10m"
        delete = "15m"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
