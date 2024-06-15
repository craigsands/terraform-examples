variable "vpc_id" {
  description = "The VPC ID of the virtual private cloud in which the SFTP server's endpoint will be hosted."
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs that are required to host your SFTP server endpoint in your VPC."
  type        = list(string)
}

variable "cidr_block" {
  description = "The source IPv4 CIDR range."
  type        = string
}

variable "pgp_passphrase" {
  description = "The passphrase for the PGP private key"
  type        = string
}

variable "pgp_private_key" {
  description = "The filename of the PGP private key."
  type        = string
  default     = "tftestuser-gpg"
}

variable "default_tags" {
  description = "Key-value map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
