provider "aws" {
  alias   = "remote"
}

provider "aws" {
  alias   = "local"
}

data "aws_caller_identity" "local" {
  provider = aws.local
}

provider "local" {}

provider "http" {}

# Note: for example only, do not use in production
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

provider "tls" {}

locals {
  local_account_id = data.aws_caller_identity.local.account_id
  my_ip_cidr       = "${chomp(data.http.myip.response_body)}/32"
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "example" {
  filename = "${path.module}/id_rsa"
  content  = tls_private_key.example.private_key_openssh
}

module "local_transfer_server" {
  source = "./modules/transfer-server"

  providers = {
    aws = aws.local
  }

  vpc_cidr_block     = "10.0.0.0/16"
  subnet_cidr_block  = "10.0.1.0/24"
  ingress_cidr_block = local.my_ip_cidr
}

module "remote_transfer_server" {
  source = "./modules/transfer-server"

  providers = {
    aws = aws.remote
  }

  vpc_cidr_block     = "10.1.0.0/16"
  subnet_cidr_block  = "10.1.1.0/24"
  ingress_cidr_block = local.my_ip_cidr
}

resource "aws_s3_bucket" "remote" {
  provider = aws.remote

  bucket_prefix = "remote-"

  force_destroy = true
}

module "local_user" {
  source = "./modules/transfer-user"

  providers = {
    aws = aws.local
  }

  user_name          = "local"
  transfer_server_id = module.local_transfer_server.transfer_server_id
  public_key         = tls_private_key.example.public_key_openssh

  # grant access to the bucket in another account
  bucket_arn = aws_s3_bucket.remote.arn
}

module "remote_user" {
  source = "./modules/transfer-user"

  providers = {
    aws = aws.remote
  }

  user_name          = "remote"
  transfer_server_id = module.remote_transfer_server.transfer_server_id
  public_key         = tls_private_key.example.public_key_openssh

  # grant access to the bucket in the same account
  bucket_arn = aws_s3_bucket.remote.arn
}

resource "aws_s3_bucket_policy" "allow_local_access_to_remote" {
  provider = aws.remote

  bucket = aws_s3_bucket.remote.id
  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": ["${local.local_account_id}"]
          },
          "Action": [
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ],
          "Resource": [
            "${aws_s3_bucket.remote.arn}"
          ]
        },
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": ["${local.local_account_id}"]
          },
          "Action": [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:DeleteObject",
            "s3:DeleteObjectVersion",
            "s3:PutObject"
          ],
          "Resource": [
            "${aws_s3_bucket.remote.arn}/*"
          ]
        }
      ]
    }
  EOF
}

resource "local_file" "test" {
  for_each = toset(["local", "remote"])
  filename = "${path.module}/test-${each.key}.txt"
  content  = "This is a test file from the ${each.key} user."
}

resource "terraform_data" "local" {
  # sftp put a test file as local user
  triggers_replace = [
    module.local_transfer_server,
    aws_s3_bucket.remote,
    module.local_user,
    local_file.test["local"]
  ]

  provisioner "local-exec" {
    command = <<-EOF
      sftp \
        -i ${local_sensitive_file.example.filename} \
        -oStrictHostKeyChecking=no \
        local@${module.local_transfer_server.public_ip} \
        <<< $'put ${local_file.test["local"].filename}'
    EOF
  }
}

resource "terraform_data" "remote" {
  # sftp put a test file as remote user
  triggers_replace = [
    module.remote_transfer_server,
    aws_s3_bucket.remote,
    module.remote_user,
    local_file.test["remote"]
  ]

  provisioner "local-exec" {
    command = <<-EOF
      sftp \
        -i ${local_sensitive_file.example.filename} \
        -oStrictHostKeyChecking=no \
        remote@${module.remote_transfer_server.public_ip} \
        <<< $'put ${local_file.test["remote"].filename}'
    EOF
  }
}
