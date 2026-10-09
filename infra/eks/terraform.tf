terraform {
  backend "s3" {
    bucket  = "bubba-project"
    key     = "state/eks/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
