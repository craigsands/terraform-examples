output "sftp_connect_string" {
  description = "The command string to connect to the SFTP server."
  value       = "sftp -i ${local_sensitive_file.private_key.filename} ${aws_transfer_user.example.user_name}@${data.aws_vpc_endpoint.transfer_server.dns_entry[0].dns_name}"
}
