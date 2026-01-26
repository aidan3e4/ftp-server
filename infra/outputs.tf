output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ftp_server.id
}

output "public_ip" {
  description = "Public IP address of the FTP server (Elastic IP)"
  value       = aws_eip.ftp_server.public_ip
}

output "public_dns" {
  description = "Public DNS name of the FTP server"
  value       = aws_instance.ftp_server.public_dns
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for FTP uploads"
  value       = aws_s3_bucket.ftp_uploads.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.ftp_uploads.arn
}

output "ftp_connection_info" {
  description = "FTP connection information"
  value = {
    host = aws_eip.ftp_server.public_ip
    port = var.ftp_port
    user = var.ftp_user
  }
  sensitive = true
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.ftp_server.public_ip}"
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = aws_ecr_repository.ftp_server.repository_url
}

output "docker_image_full_path" {
  description = "Full Docker image path with tag"
  value       = "${aws_ecr_repository.ftp_server.repository_url}:${var.docker_image_tag}"
}
