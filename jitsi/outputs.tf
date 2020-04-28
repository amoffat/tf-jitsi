output "public_ip" {
  value = aws_instance.jitsi.public_ip
}

output "domain" {
  value = "${local.subdomain}.${data.aws_route53_zone.jitsi.name}"
}