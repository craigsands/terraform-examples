output "local_user_connection_string" {
  description = "The SFTP connection string for the local user."
  value = join(" ", [
    "sftp",
    "-i ${local_sensitive_file.example.filename}",
    "local@${module.local_transfer_server.public_ip}"
  ])
}

output "remote_user_connection_string" {
  description = "The SFTP connection string for the remote user."
  value = join(" ", [
    "sftp",
    "-i ${local_sensitive_file.example.filename}",
    "local@${module.remote_transfer_server.public_ip}"
  ])
}
