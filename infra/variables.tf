variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ftp-server"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "key_pair_name" {
  description = "Name of the SSH key pair for EC2 access"
  type        = string
}

variable "ssh_allowed_ips" {
  description = "List of IP addresses allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Change this to your IP for better security
}

variable "s3_bucket_name" {
  description = "Name of S3 bucket for FTP uploads (must be globally unique)"
  type        = string
}

variable "s3_prefix" {
  description = "Prefix for uploaded files in S3"
  type        = string
  default     = "ftp_uploads/"
}

variable "enable_s3_lifecycle" {
  description = "Enable S3 lifecycle policy to delete old files"
  type        = bool
  default     = false
}

variable "s3_lifecycle_days" {
  description = "Number of days after which to delete files from S3"
  type        = number
  default     = 90
}

variable "ftp_user" {
  description = "FTP username"
  type        = string
  default     = "reolink"
  sensitive   = true
}

variable "ftp_password" {
  description = "FTP password"
  type        = string
  sensitive   = true
}

variable "ftp_port" {
  description = "FTP server port"
  type        = number
  default     = 2121
}

variable "repository_url" {
  description = "Git repository URL for the FTP server code (optional, if using git deployment)"
  type        = string
  default     = ""
}

variable "repository_branch" {
  description = "Git repository branch to deploy"
  type        = string
  default     = "main"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for Docker images"
  type        = string
  default     = "ftp-server"
}

variable "docker_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
