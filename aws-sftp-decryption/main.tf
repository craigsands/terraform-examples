provider "aws" {
  default_tags {
    tags = var.default_tags
  }
}

provider "local" {}

provider "tls" {}

resource "aws_s3_bucket" "example" {
  bucket = "transfer-test-bucket-${local.account_id}"
}

resource "aws_security_group" "allow_sftp" {
  name        = "allow_sftp"
  description = "Allow SFTP inbound traffic and all outbound traffic"
  vpc_id      = data.aws_vpc.selected.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_sftp_ipv4" {
  security_group_id = aws_security_group.allow_sftp.id
  cidr_ipv4         = var.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_iam_role" "logging" {
  name_prefix = "transfer-logging-"
  assume_role_policy = templatefile(
    "${path.module}/templates/transfer-logging-trust-policy.tftpl",
    {
      account_id = local.account_id
      region     = local.region
    }
  )
  inline_policy {
    name   = "transfer-logging-policy"
    policy = file("${path.module}/policies/transfer-logging-role-policy.json")
  }
}

resource "aws_transfer_workflow" "example" {
  description = "Test Workflow"

  steps {
    decrypt_step_details {
      destination_file_location {
        s3_file_location {
          bucket = aws_s3_bucket.example.id
          key    = "home/$${transfer:UserName}/decrypted-files/"
        }
      }
      name                 = "decrypt"
      source_file_location = "$${previous.file}"
      type                 = "PGP"
    }
    type = "DECRYPT"
  }

  steps {
    copy_step_details {
      destination_file_location {
        s3_file_location {
          bucket = aws_s3_bucket.example.id
          key    = "home/$${transfer:UserName}/archived-files/"
        }
      }
      name                 = "archive"
      source_file_location = "$${original.file}"
    }
    type = "COPY"
  }

  steps {
    delete_step_details {
      name                 = "delete"
      source_file_location = "$${original.file}"
    }
    type = "DELETE"
  }

  on_exception_steps {
    copy_step_details {
      destination_file_location {
        s3_file_location {
          bucket = aws_s3_bucket.example.id
          key    = "home/$${transfer:UserName}/exceptions/"
        }
      }
      name                 = "copy"
      source_file_location = "$${previous.file}"
    }
    type = "COPY"
  }

  on_exception_steps {
    delete_step_details {
      name                 = "delete"
      source_file_location = "$${original.file}"
    }
    type = "DELETE"
  }
}

resource "aws_iam_role" "workflow" {
  name_prefix = "transfer-workflow-"
  assume_role_policy = templatefile(
    "${path.module}/templates/transfer-workflow-trust-policy.tftpl",
    {
      account_id  = local.account_id
      region      = local.region
      workflow_id = aws_transfer_workflow.example.id
    }
  )
  inline_policy {
    name = "transfer-workflow-policy"
    policy = templatefile(
      "${path.module}/templates/transfer-workflow-role-policy.tftpl",
      {
        account_id = local.account_id
        bucket_arn = aws_s3_bucket.example.arn
        region     = local.region
      }
    )
  }
}

resource "aws_transfer_server" "example" {
  endpoint_type = "VPC"

  endpoint_details {
    security_group_ids = [aws_security_group.allow_sftp.id]
    subnet_ids         = var.subnet_ids
    vpc_id             = data.aws_vpc.selected.id
  }

  logging_role         = aws_iam_role.logging.arn
  force_destroy        = true
  security_policy_name = "TransferSecurityPolicy-2020-06"

  workflow_details {
    on_upload {
      execution_role = aws_iam_role.workflow.arn
      workflow_id    = aws_transfer_workflow.example.id
    }
  }
}

resource "aws_iam_role" "user" {
  name_prefix = "transfer-user-"
  assume_role_policy = templatefile(
    "${path.module}/templates/transfer-user-trust-policy.tftpl",
    {
      account_id = local.account_id
      region     = local.region
    }
  )
  inline_policy {
    name = "transfer-user-policy"
    policy = templatefile(
      "${path.module}/templates/transfer-user-role-policy.tftpl",
      {
        bucket_arn = aws_s3_bucket.example.arn
      }
    )
  }
}

resource "aws_transfer_user" "example" {
  server_id = aws_transfer_server.example.id
  user_name = local.transfer_user_name
  role      = aws_iam_role.user.arn

  home_directory_type = "LOGICAL"
  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.example.id}/home/${local.transfer_user_name}"
  }

  policy = templatefile(
    "${path.module}/templates/transfer-user-session-policy.tftpl",
    {
      bucket_arn = aws_s3_bucket.example.arn
    }
  )
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_transfer_ssh_key" "example" {
  server_id = aws_transfer_server.example.id
  user_name = aws_transfer_user.example.user_name
  body      = trimspace(tls_private_key.example.public_key_openssh)
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.example.private_key_openssh
  filename        = "${path.module}/id_rsa"
}

resource "aws_secretsmanager_secret" "example" {
  name                    = "aws/transfer/${aws_transfer_server.example.id}/${aws_transfer_user.example.user_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id = aws_secretsmanager_secret.example.id
  secret_string = jsonencode({
    PGPPrivateKey = file("${path.module}/${var.pgp_private_key}")
    PGPPassphrase = var.pgp_passphrase
  })
}
