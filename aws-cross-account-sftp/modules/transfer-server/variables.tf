variable "ingress_cidr_block" {
  description = "The CIDR block allowed through the AWS Transfer Family server security group."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block to assign to the VPC."
  type        = string
}

variable "subnet_cidr_block" {
  description = "The CIDR block to assign to the VPC subnet."
  type        = string
}

variable "security_policy_name" {
  description = "Specifies the name of the security policy that is attached to the server."
  type        = string
  default     = "TransferSecurityPolicy-2018-11"
}
