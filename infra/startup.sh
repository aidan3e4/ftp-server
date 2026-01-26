#!/bin/bash
# Startup script - Recreates EC2 instance and Elastic IP
# Note: You will get a NEW IP address each time

set -e

echo "🚀 Starting up FTP server infrastructure..."
echo ""
echo "This will create:"
echo "  - New EC2 instance"
echo "  - New Elastic IP (⚠️  IP address will be different)"
echo ""
echo "Existing resources (S3, ECR, IAM) will remain unchanged."
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

terraform apply \
  -target=aws_eip.ftp_server \
  -target=aws_instance.ftp_server \
  -target=aws_eip_association.ftp_server

echo ""
echo "✅ Startup complete!"
echo ""
echo "New connection details:"
terraform output ftp_connection_info
echo ""
echo "⚠️  Remember to update your FTP client/camera with the new IP address!"
