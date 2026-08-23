terraform {
  backend "s3" {
    bucket  = "bubba"
    key     = "state/vpc/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
