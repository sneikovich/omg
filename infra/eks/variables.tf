variable "instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
