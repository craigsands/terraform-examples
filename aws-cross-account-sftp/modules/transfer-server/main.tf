data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.name
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_subnet" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.subnet_cidr_block
}

resource "aws_security_group" "this" {
  name_prefix = "transfer-server-"
  description = "Allow SFTP inbound traffic."
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_sftp_ipv4" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = var.ingress_cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_eip" "this" {
  domain = "vpc"
}

resource "aws_iam_role" "logging" {
  name_prefix = "transfer-logging-"

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "transfer.amazonaws.com"
          },
          "Action": "sts:AssumeRole",
          "Condition": {
            "StringEquals": {
              "aws:SourceAccount": "${local.account_id}"
            },
            "ArnLike": {
              "aws:SourceArn": [
                "arn:aws:transfer:${local.region}:${local.account_id}:server/*",
                "arn:aws:transfer:${local.region}:${local.account_id}:workflow/*"
              ]
            }
          }
        }
      ]
    }
  EOF

  inline_policy {
    name   = "transfer-logging-role-policy"
    policy = <<-EOF
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "logs:CreateLogStream",
              "logs:DescribeLogStreams",
              "logs:CreateLogGroup",
              "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:/aws/transfer/*"
          }
        ]
      }
    EOF
  }
}

resource "aws_transfer_server" "this" {
  endpoint_type = "VPC"

  endpoint_details {
    address_allocation_ids = [aws_eip.this.id]
    security_group_ids     = [aws_security_group.this.id]
    subnet_ids             = [aws_subnet.this.id]
    vpc_id                 = aws_vpc.this.id
  }

  force_destroy        = true
  logging_role         = aws_iam_role.logging.arn
  security_policy_name = var.security_policy_name
}

resource "aws_route" "this" {
  route_table_id         = aws_vpc.this.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
