#!/bin/bash
set -e

# Log output to file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting FTP server setup with Docker..."

# Update system
yum update -y

# Install Docker
yum install -y docker

# Start Docker service
systemctl start docker
systemctl enable docker

# Get AWS region from instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${s3_region} | docker login --username AWS --password-stdin ${ecr_registry}

# Pull Docker image
echo "Pulling Docker image from ECR..."
docker pull ${docker_image}

# Create .env file for the container
APP_DIR="/opt/ftp_server"
mkdir -p $APP_DIR
cat > $APP_DIR/.env << 'ENV_FILE'
FTP_USER=${ftp_user}
FTP_PASSWORD=${ftp_password}
FTP_PORT=${ftp_port}
FTP_HOST=0.0.0.0
FTP_MAX_CONS=256
FTP_MAX_CONS_PER_IP=5
FTP_PERMISSIONS=elradfmwMT

S3_BUCKET=${s3_bucket}
S3_REGION=${s3_region}
S3_PREFIX=${s3_prefix}

MASQUERADE_ADDRESS=${masquerade_address}
ENV_FILE

# Create systemd service for Docker container
cat > /etc/systemd/system/ftp-server.service << 'SERVICE_FILE'
[Unit]
Description=FTP Server Docker Container
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ftp_server
ExecStartPre=-/usr/bin/docker stop ftp-server
ExecStartPre=-/usr/bin/docker rm ftp-server
ExecStart=/usr/bin/docker run \
  --name ftp-server \
  --rm \
  -p 2121:2121 \
  -p 60000-60100:60000-60100 \
  --env-file /opt/ftp_server/.env \
  ${docker_image}
ExecStop=/usr/bin/docker stop ftp-server
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_FILE

# Enable and start the service
systemctl daemon-reload
systemctl enable ftp-server.service
systemctl start ftp-server.service

echo "FTP server setup complete!"
echo "Service status:"
systemctl status ftp-server.service --no-pager || true

# Check if service is running
sleep 5
if systemctl is-active --quiet ftp-server.service; then
    echo "✓ FTP server is running successfully"
    echo "✓ Docker container is up"
    docker ps | grep ftp-server || true
else
    echo "✗ FTP server failed to start. Check logs with: journalctl -u ftp-server.service"
fi
