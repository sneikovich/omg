terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}

provider "helm" {
  kubernetes = {
    # config_path            = var.k8s_path
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  #   config_path            = var.k8s_path
  host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

#  data блок. eks state
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "bubba-project"
    key    = "state/eks/terraform.tfstate" # шлях до eks стейту
    region = "eu-central-1"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}
