variable "user_name" {
  description = "The name of the AWS Transfer Family user."
  type        = string
}

variable "bucket_arn" {
  description = "The ARN of the backend S3 bucket."
  type        = string
}

variable "transfer_server_id" {
  description = "The ID of the AWS Transfer Family server."
  type        = string
}

variable "public_key" {
  description = "The public key portion of an SSH key pair."
  type        = string
}
