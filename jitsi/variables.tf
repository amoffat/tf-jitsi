variable "instance_type" {
  default = "t2.micro"
}

variable "tf_jitsi_branch" {
  default = "master"
}

variable "jitsi_branch" {
  default = "master"
}

variable "region" {
  default = "us-west-2"
}

variable key_name {
  default = "tf-jitsi"
}

variable aws_profile {
  default = "tf-jitsi"
}

variable dns_zone {}

variable "cert" {}