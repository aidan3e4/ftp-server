# FTP Server Infrastructure - Terraform

This directory contains Terraform configuration to deploy the FTP server on AWS.

## Architecture

The infrastructure includes:
- **EC2 Instance** running Amazon Linux 2023 with the FTP server (in default VPC)
- **Elastic IP** for stable public address
- **S3 Bucket** for storing uploaded files
- **IAM Role** with permissions to write to S3
- **Security Group** allowing FTP (port 2121), passive ports (60000-60100), and SSH

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set the following required variables:
- `key_pair_name` - Name of your AWS SSH key pair
- `s3_bucket_name` - Globally unique S3 bucket name
- `ftp_password` - Secure password for FTP access
- `ssh_allowed_ips` - Your IP address for SSH access (recommended)

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

This shows what resources will be created.

Note that both `plan` and `apply` require to be logged in to AWS. We can either export the credits or the entire AWS_PROFILE. See the profiles with `aws configure list-profiles`.

### 4. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

The deployment takes 3-5 minutes. At the end, you'll see outputs including:
- Public IP address
- FTP connection information
- SSH command

### 5. Verify Deployment

```bash
# Get the public IP
terraform output public_ip

# SSH into the instance
terraform output -raw ssh_command | bash

# Check FTP server status
sudo systemctl status ftp-server

# View logs
sudo journalctl -u ftp-server -f
```

## Configuration Options

### Security

**Important**: Restrict SSH access to your IP:
```hcl
ssh_allowed_ips = ["YOUR.IP.ADDRESS.HERE/32"]
```

Find your IP: `curl ifconfig.me`

### Git Deployment

To automatically deploy code from a Git repository:
```hcl
repository_url    = "https://github.com/yourusername/ftp-server.git"
repository_branch = "main"
```

**Note**: If using a private repository, you'll need to configure SSH keys or access tokens.

## Manual Code Deployment

If not using Git deployment, upload code manually:

```bash
# Get the public IP
PUBLIC_IP=$(terraform output -raw public_ip)
KEY_FILE="~/.ssh/your-key.pem"

# Upload code
scp -i $KEY_FILE -r ../server.py ../pyproject.toml ../uv.lock ec2-user@$PUBLIC_IP:/tmp/

# SSH and move files
ssh -i $KEY_FILE ec2-user@$PUBLIC_IP

# On the server
sudo cp /tmp/server.py /opt/ftp_server/
sudo cp /tmp/pyproject.toml /opt/ftp_server/
sudo cp /tmp/uv.lock /opt/ftp_server/

# Install dependencies
cd /opt/ftp_server
sudo pip3 install -r pyproject.toml

# Restart service
sudo systemctl restart ftp-server
```

## Connecting to FTP

Use the outputs to connect:

```bash
# Get connection info
terraform output ftp_connection_info
```

From your Reolink camera or FTP client:
- **Host**: (public IP from output)
- **Port**: 2121
- **Username**: reolink (or your configured username)
- **Password**: (from your terraform.tfvars)
- **Mode**: Passive

### Test Connection

```bash
# Using lftp
lftp -u reolink,your-password -p 2121 YOUR_PUBLIC_IP

# Or using ftp command
ftp
> open YOUR_PUBLIC_IP 2121
> user reolink
> pass your-password
```

## Monitoring

### View Logs

```bash
# SSH into instance
ssh -i ~/.ssh/your-key.pem ec2-user@YOUR_PUBLIC_IP

# View real-time logs
sudo journalctl -u ftp-server -f

# View all logs
sudo journalctl -u ftp-server --no-pager

# View user data execution logs
sudo cat /var/log/user-data.log
```

### Check S3 Uploads

```bash
# List files in S3
aws s3 ls s3://your-bucket-name/ftp_uploads/ --recursive
```

## Troubleshooting

### FTP Server Not Running

```bash
# Check service status
sudo systemctl status ftp-server

# View recent logs
sudo journalctl -u ftp-server -n 50

# Restart service
sudo systemctl restart ftp-server
```

### Can't Connect to FTP

1. Check security group allows your IP
2. Verify Elastic IP is attached: `terraform output public_ip`
3. Test port connectivity:
   ```bash
   telnet YOUR_PUBLIC_IP 2121
   ```
4. Check if passive ports are accessible (60000-60100)

### S3 Upload Failures

1. Verify IAM role is attached to instance
2. Check S3 bucket name in `/opt/ftp_server/.env`
3. View logs for S3 errors:
   ```bash
   sudo journalctl -u ftp-server | grep -i s3
   ```

## Updating the Infrastructure

### Update Code

If code changes:
```bash
# Either push to Git repo (if using Git deployment)
# Or manually SCP new files and restart service

# Then recreate instance to run updated user_data
terraform taint aws_instance.ftp_server
terraform apply
```

### Update Configuration

1. Edit `terraform.tfvars`
2. Run `terraform apply`

Note: Some changes may require instance recreation (like changing user_data).

## Costs

Estimated monthly costs (us-east-1, as of 2025):
- EC2 t3.small: ~$15/month
- Elastic IP: Free while attached, $3.6/month if not
- S3 storage: ~$0.023/GB/month
- Data transfer: ~$0.09/GB out to internet

**Total**: ~$15-20/month + storage and transfer

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete:
- EC2 instance
- Elastic IP
- S3 bucket (if empty)
- VPC and all networking

The S3 bucket must be empty before destruction. Empty it first:
```bash
aws s3 rm s3://your-bucket-name --recursive
```

## Security Best Practices

1. **Change default passwords** in `terraform.tfvars`
2. **Restrict SSH access** to your IP only
3. **Enable S3 encryption** (add to main.tf if needed)
4. **Use strong FTP passwords** (16+ characters)
5. **Regularly update** the instance:
   ```bash
   sudo yum update -y
   ```
6. **Monitor S3 access logs** (enable in S3 console)
7. **Consider VPN** for even more secure access

## Advanced Configuration

### Enable S3 Encryption

Add to `main.tf` in the S3 bucket resource:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "ftp_uploads" {
  bucket = aws_s3_bucket.ftp_uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### Add CloudWatch Monitoring

Add to `main.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "ftp_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = []  # Add SNS topic ARN for notifications

  dimensions = {
    InstanceId = aws_instance.ftp_server.id
  }
}
```

### Multiple Environments

Create separate tfvars files:

```bash
# Production
terraform apply -var-file="production.tfvars"

# Staging
terraform apply -var-file="staging.tfvars"
```

## Support

For issues with:
- **Infrastructure**: Check this README and AWS documentation
- **FTP Server**: See main project README
- **Terraform**: https://www.terraform.io/docs
