#############################
# Primary Region: us-east-1 #
#############################
provider "aws" {
  region = "us-east-1"
}

resource "aws_kms_key" "example" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 7
}

resource "aws_s3_bucket" "example" {
  bucket_prefix = "cross-region-decryption-"

  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.example.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_object" "example" {
  bucket  = aws_s3_bucket.example.id
  key     = "someobject"
  content = "Hello World!"

  # The following is not required; S3 will automatically use the primary key by default
  # kms_key_id = aws_kms_key.example.arn
}

###############################
# Secondary Region: us-east-2 #
###############################
provider "aws" {
  alias  = "use2"
  region = "us-east-2"
}

data "aws_region" "use2" {
  provider = aws.use2
}

resource "terraform_data" "decrypt" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    # download the file from the same region as the bucket
    command = <<-EOF
      echo "$(
        aws s3 cp \
          --region ${aws_s3_bucket.example.region} \
          s3://${aws_s3_bucket.example.id}/${aws_s3_object.example.key} \
          - \
          --debug 2> ${aws_s3_bucket.example.region}.log
      )"
    EOF
  }

  provisioner "local-exec" {
    # download the file from an alternative region from the bucket
    command = <<-EOF
      echo "$(
        aws s3 cp \
          --region ${data.aws_region.use2.name} \
          s3://${aws_s3_bucket.example.id}/${aws_s3_object.example.key} \
          - \
          --debug 2> ${data.aws_region.use2.name}.log
      )"
    EOF
  }
}
