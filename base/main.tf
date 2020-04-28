provider "aws" {
  region = terraform.workspace
}

terraform {
  backend "local" {
  }
}

locals {
  region = terraform.workspace
  az = "${local.region}a"
  common_tags = {
    Project = "tf-jitsi"
  }
}

resource "aws_vpc" "main" {
  enable_dns_hostnames = true
  cidr_block           = "10.0.0.0/16"
  tags = local.common_tags
}

resource "aws_route" "route" {
  route_table_id            = aws_vpc.main.main_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/16"
  availability_zone = local.az
  map_public_ip_on_launch = true

  tags = local.common_tags
}