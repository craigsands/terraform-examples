data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

resource "aws_iam_role" "this" {
  name_prefix = "${var.user_name}-"

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
              "aws:SourceArn": "arn:aws:transfer:${local.region}:${local.account_id}:user/*"
            }
          }
        }
      ]
    }
  EOF

  inline_policy {
    name = "allow-s3"

    policy = <<-EOF
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": [
              "s3:ListBucket",
              "s3:GetBucketLocation"
            ],
            "Resource": [
              "${var.bucket_arn}"
            ]
          },
          {
            "Effect": "Allow",
            "Action": [
              "s3:GetObject",
              "s3:GetObjectVersion",
              "s3:DeleteObject",
              "s3:DeleteObjectVersion",
              "s3:PutObject"
            ],
            "Resource": [
              "${var.bucket_arn}/*"
            ]
          }
        ]
      }
    EOF
  }
}

resource "aws_transfer_user" "this" {
  server_id = var.transfer_server_id
  user_name = var.user_name
  role      = aws_iam_role.this.arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${element(split(":", var.bucket_arn), 5)}/home/${var.user_name}"
  }

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ],
          "Resource": [
            "${var.bucket_arn}"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:PutObject"
          ],
          "Resource": [
            "${var.bucket_arn}/home/${var.user_name}/*"
          ]
        }
      ]
    }
  EOF
}

resource "aws_transfer_ssh_key" "this" {
  server_id = var.transfer_server_id
  user_name = aws_transfer_user.this.user_name
  body      = trimspace(var.public_key)
}
