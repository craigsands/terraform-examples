provider "aws" {
  default_tags {
    tags = {
      "project" : "terraform-examples/aws-sftp-scheduled"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  user_name = "tftestuser"
}

resource "tls_private_key" "this" {
  for_each = toset(["host", "user"])

  # The algorithm here must be RSA. When used with ED25519,
  # the server doesn't expose the host key until after a connection is made,
  # preventing the server and SFTP connector from being created
  # within the same Terraform run as this example demonstrates.
  algorithm = "RSA"
}

resource "aws_s3_bucket" "this" {
  bucket        = "sftp-scheduled-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_object" "in_folder" {
  bucket = aws_s3_bucket.this.bucket
  key    = "in/"
}

module "logger_role" {
  source = "./modules/service-role"

  service_principal = "transfer.amazonaws.com"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:log-group:/aws/transfer/*"
      }
    ]
  })
}

resource "aws_transfer_server" "this" {
  # The following (set by default and thus omitted) are required for this example
  # domain        = "S3"
  # protocols     = ["SFTP"]
  # endpoint_type = "PUBLIC"

  host_key      = trimspace(tls_private_key.this["host"].private_key_pem)
  logging_role  = module.logger_role.iam_role_arn
  force_destroy = true # delete users along with the server
}

resource "aws_cloudwatch_log_group" "server" {
  name = "/aws/transfer/${aws_transfer_server.this.id}"
}

resource "aws_secretsmanager_secret" "this" {
  recovery_window_in_days = 0 # allow immediate deletion
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    "Username" : local.user_name,
    "PrivateKey" : tls_private_key.this["user"].private_key_openssh
  })
}

module "connector_role" {
  source = "./modules/service-role"

  service_principal = "transfer.amazonaws.com"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.this.arn}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion"
        ],
        "Resource" : "${aws_s3_bucket.this.arn}/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "${aws_secretsmanager_secret.this.arn}"
      }
    ]
  })
}

resource "aws_transfer_user" "this" {
  server_id = aws_transfer_server.this.id
  user_name = local.user_name
  role      = module.connector_role.iam_role_arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/${trim(aws_s3_object.in_folder.key, "/")}"
    target = "/${aws_s3_bucket.this.id}"
  }
}

resource "aws_transfer_ssh_key" "this" {
  server_id = aws_transfer_server.this.id
  user_name = aws_transfer_user.this.user_name
  body      = trimspace(tls_private_key.this["user"].public_key_openssh)
}

resource "aws_transfer_connector" "this" {
  access_role  = module.connector_role.iam_role_arn
  logging_role = module.logger_role.iam_role_arn
  sftp_config {
    trusted_host_keys = [trimspace(tls_private_key.this["host"].public_key_openssh)]
    user_secret_id    = aws_secretsmanager_secret.this.id
  }
  url = "sftp://${aws_transfer_server.this.endpoint}"

  # create the user before trying to connect
  depends_on = [aws_transfer_user.this]
}

resource "aws_cloudwatch_log_group" "connector" {
  name = "/aws/transfer/${aws_transfer_connector.this.connector_id}"
}

module "scheduler_role" {
  source = "./modules/service-role"

  service_principal = "scheduler.amazonaws.com"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_s3_bucket.this.arn}"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObjectVersion"
        ],
        "Resource" : "${aws_s3_bucket.this.arn}/*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "${aws_secretsmanager_secret.this.arn}"
      }
    ]
  })
}

resource "aws_scheduler_schedule" "schedule" {
  flexible_time_window {
    mode = "OFF"
  }
  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "America/New_York"
  target {
    arn      = aws_transfer_connector.this.arn
    role_arn = module.scheduler_role.iam_role_arn
    input    = jsonencode({})
  }
}
