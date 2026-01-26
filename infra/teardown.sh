#!/bin/bash
# Teardown script - Destroys costly resources while keeping data
# This removes: EC2 instance, Elastic IP
# This keeps: S3 bucket, ECR repository, IAM roles, security groups

set -e

echo "🗑️  Tearing down FTP server infrastructure..."
echo ""
echo "This will destroy:"
echo "  - EC2 instance (stops compute charges)"
echo "  - Elastic IP (stops EIP charges)"
echo ""
echo "This will keep:"
echo "  - S3 bucket with uploaded files"
echo "  - ECR repository with Docker images"
echo "  - IAM roles and security groups"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

terraform destroy \
  -target=aws_eip_association.ftp_server \
  -target=aws_instance.ftp_server \
  -target=aws_eip.ftp_server

echo ""
echo "✅ Teardown complete! No more hourly charges."
echo "Run ./startup.sh when you're ready to bring it back up."
