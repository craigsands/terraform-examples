data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_vpc_endpoint" "transfer_server" {
  id = aws_transfer_server.example.endpoint_details[0].vpc_endpoint_id
}
