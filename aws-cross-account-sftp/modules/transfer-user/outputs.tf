output "iam_role_arn" {
  description = "The ARN of the role assigned to the AWS Transfer Family user."
  value       = aws_iam_role.this.arn
}
