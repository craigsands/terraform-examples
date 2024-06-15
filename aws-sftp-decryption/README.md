# AWS SFTP Decryption

Deploy an AWS Transfer Family server and decryption workflow.

### Notes

- Prematurly creating the home folder in the S3 bucket for a user is not required when
  `home_directory_type = "LOGICAL"` for that user.
