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
