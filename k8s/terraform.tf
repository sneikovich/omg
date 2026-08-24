terraform {
  backend "s3" {
    bucket  = "bubba-project"
    key     = "state/k8s/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
