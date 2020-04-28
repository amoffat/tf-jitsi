output "vpc" {
  value = aws_vpc.main.id
}

output "subnet" {
  value = aws_subnet.main.id
}

output "az" {
  value = aws_subnet.main.availability_zone
}