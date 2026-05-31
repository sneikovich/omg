terraform {
  backend "s3" {
    bucket  = "teno-wa-01"
    key     = "state/vpc/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}
