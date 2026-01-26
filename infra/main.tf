terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# Data source for latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Use the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get a default subnet (picks the first available one)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "ftp_server" {
  name        = "${var.project_name}-ftp-sg"
  description = "Security group for FTP server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_ips
    description = "SSH access"
  }

  # FTP control port
  ingress {
    from_port   = var.ftp_port
    to_port     = var.ftp_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FTP control port"
  }

  # FTP passive ports
  ingress {
    from_port   = 60000
    to_port     = 60100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "FTP passive ports"
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-ftp-sg"
  }
}

# S3 Bucket for FTP uploads
resource "aws_s3_bucket" "ftp_uploads" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "${var.project_name}-ftp-uploads"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "ftp_uploads" {
  bucket = aws_s3_bucket.ftp_uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Lifecycle Rule (optional - delete old files after 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "ftp_uploads" {
  count  = var.enable_s3_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.ftp_uploads.id

  rule {
    id     = "delete-old-uploads"
    status = "Enabled"

    filter {}  # Empty filter applies to all objects

    expiration {
      days = var.s3_lifecycle_days
    }
  }
}

# ECR Repository for Docker images
resource "aws_ecr_repository" "ftp_server" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-ftp-server"
  }
}

# ECR Lifecycle Policy (keep only last 10 images)
resource "aws_ecr_lifecycle_policy" "ftp_server" {
  repository = aws_ecr_repository.ftp_server.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# IAM Role for EC2
resource "aws_iam_role" "ftp_server" {
  name = "${var.project_name}-ftp-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ftp-server-role"
  }
}

# IAM Policy for S3 access
resource "aws_iam_role_policy" "ftp_server_s3" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.ftp_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ftp_uploads.arn,
          "${aws_s3_bucket.ftp_uploads.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for ECR access
resource "aws_iam_role_policy" "ftp_server_ecr" {
  name = "${var.project_name}-ecr-access"
  role = aws_iam_role.ftp_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ftp_server" {
  name = "${var.project_name}-ftp-server-profile"
  role = aws_iam_role.ftp_server.name
}

# Elastic IP for stable public address
resource "aws_eip" "ftp_server" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-ftp-eip"
  }
}

# EC2 Instance
resource "aws_instance" "ftp_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.ftp_server.id]
  iam_instance_profile   = aws_iam_instance_profile.ftp_server.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    ftp_user           = var.ftp_user
    ftp_password       = var.ftp_password
    ftp_port           = var.ftp_port
    s3_bucket          = aws_s3_bucket.ftp_uploads.id
    s3_region          = var.aws_region
    s3_prefix          = var.s3_prefix
    masquerade_address = aws_eip.ftp_server.public_ip
    ecr_registry       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    docker_image       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${aws_ecr_repository.ftp_server.name}:${var.docker_image_tag}"
  })

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-ftp-server"
  }
}

# Associate Elastic IP with EC2 Instance
resource "aws_eip_association" "ftp_server" {
  instance_id   = aws_instance.ftp_server.id
  allocation_id = aws_eip.ftp_server.id
}
