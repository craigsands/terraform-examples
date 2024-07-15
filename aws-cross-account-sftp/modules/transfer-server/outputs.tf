output "transfer_server_id" {
  description = "The ID of the AWS Transfer Family server."
  value       = aws_transfer_server.this.id
}

output "public_ip" {
  description = "The public IP address for the AWS Transfer Family server."
  value       = aws_eip.this.public_ip
}
