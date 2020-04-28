provider "aws" {
  region = var.region
  profile = var.aws_profile
}

terraform {
  backend "local" {
  }
}

data "terraform_remote_state" "base_infr" {
  backend = "local"
  config = {
    path = "${path.module}/../base/terraform.tfstate.d/${var.region}/terraform.tfstate"
  }
}

locals {
  dns_zone = var.dns_zone
  az =  data.terraform_remote_state.base_infr.outputs.az

  # amazon linux 2 images
  amis = {
    us-east-1 = "ami-0323c3dd2da7fb37d"
    us-east-2 = "ami-0f7919c33c90f5b58"
    us-west-1 = "ami-06fcc1f0bc2c8943f"
    us-west-2 = "ami-0d6621c01e8c2de2c"
  }
  subnet = data.terraform_remote_state.base_infr.outputs.subnet
  vpc = data.terraform_remote_state.base_infr.outputs.vpc
  subdomain = terraform.workspace

  common_tags = {
    Project = "tf-jitsi"
  }
}

data aws_route53_zone "jitsi" {
  zone_id = local.dns_zone
}

data template_file "jitsi" {
  template = file("${path.root}/cloud_configs/default.yml")
  vars = {
    tf_jitsi_branch = var.tf_jitsi_branch
    jitsi_branch = var.jitsi_branch
  }
}

resource "aws_instance" "jitsi" {
  instance_type = var.instance_type
  ami           = local.amis[var.region]
  key_name      = var.key_name
  availability_zone = local.az

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.main.id
  }

  user_data = data.template_file.jitsi.rendered
  tags = merge(local.common_tags, map("Name", local.subdomain))
}

resource "aws_route53_record" "client_name" {
  zone_id = local.dns_zone
  name    = local.subdomain
  type    = "A"

  alias {
    name = aws_lb.main.dns_name
    zone_id = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}

resource "aws_lb" "main" {
  internal           = false
  load_balancer_type = "network"
  security_groups    = []
  subnets = [local.subnet]

  tags = local.common_tags
}

resource "aws_security_group" "network_card" {
  name_prefix = "${local.subdomain}-"
  vpc_id      = local.vpc

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
    description = "ssl"
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
    description = ""
  }

  ingress {
    from_port = 81
    to_port   = 81
    protocol  = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
    description = ""
  }


  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
    "0.0.0.0/0"]
    description = "ssh"
  }

  ingress {
    from_port = 4443
    to_port   = 4443
    protocol  = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
    description = "videobridge"
  }

  ingress {
    from_port = 10000
    to_port   = 10000
    protocol  = "udp"
    cidr_blocks = [
      "0.0.0.0/0"]
    description = "videobridge"
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_network_interface" "main" {
  subnet_id = local.subnet
  security_groups = [
  aws_security_group.network_card.id]

  tags = local.common_tags
}

resource "aws_lb_target_group_attachment" "web_https" {
  target_group_arn = aws_lb_target_group.web_https.arn
  target_id        = aws_instance.jitsi.id
}

resource "aws_lb_target_group_attachment" "web_http" {
  target_group_arn = aws_lb_target_group.web_http.arn
  target_id        = aws_instance.jitsi.id
}

resource "aws_lb_target_group_attachment" "jvb_tcp" {
  target_group_arn = aws_lb_target_group.jvb_tcp.arn
  target_id        = aws_instance.jitsi.id
}

resource "aws_lb_target_group_attachment" "jvb_udp" {
  target_group_arn = aws_lb_target_group.jvb_udp.arn
  target_id        = aws_instance.jitsi.id
}

resource "aws_lb_target_group" "web_https" {
  name     = "${local.subdomain}-web-https"
  port     = 80
  protocol = "TCP"
  vpc_id   = local.vpc
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "web_http" {
  name     = "${local.subdomain}-web-http"
  port     = 81
  protocol = "TCP"
  vpc_id   = local.vpc
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "jvb_tcp" {
  name     = "${local.subdomain}-jvb-tcp"
  port     = 4443
  protocol = "TCP"
  vpc_id   = local.vpc
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "jvb_udp" {
  name     = "${local.subdomain}-jvb-udp"
  port     = 10000
  protocol = "UDP"
  vpc_id   = local.vpc
  tags = local.common_tags
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "TLS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_https.arn
  }
}

resource "aws_lb_listener" "web_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_http.arn
  }
}

resource "aws_lb_listener" "jvb_tcp" {
  load_balancer_arn = aws_lb.main.arn
  port              = 4443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jvb_tcp.arn
  }
}

resource "aws_lb_listener" "jvb_udp" {
  load_balancer_arn = aws_lb.main.arn
  port              = 10000
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jvb_udp.arn
  }
}