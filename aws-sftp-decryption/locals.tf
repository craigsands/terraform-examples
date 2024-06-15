locals {
  account_id         = data.aws_caller_identity.current.account_id
  transfer_user_name = "tftestuser"
  region             = data.aws_region.current.name
}
