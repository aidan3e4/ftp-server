# Docker Deployment Guide

This guide explains how to deploy the FTP server using Docker and AWS ECR.

## Overview

The infrastructure now uses Docker for deployment:
1. Build Docker image locally
2. Push to AWS ECR (Elastic Container Registry)
3. EC2 instance pulls and runs the image automatically

## Log-into AWS

Logging into AWS can be done via sso with `aws sso login --profile PROFILE_NAME` but then we should export `export AWS_PROFILE=PROFILE_NAME` to use this login method. Otherwise just export the usual `AWS_*` env vars (access_id, password/token)

## Quick Resume (after all infra is already setup)

Use the `startup.sh` and `teardown.sh` scripts for stopping / resuming the service. This requires logging into AWS, see section above.


## Quick Start (setup all infra for 1st time)

### 0. Prerequisites

This requires logging into AWS, see section above.

### 1. Create Infrastructure

```bash
cd infra
terraform init
terraform apply
```

This creates:
- ECR repository for Docker images
- EC2 instance with Docker installed
- IAM permissions for EC2 to pull from ECR
- S3 bucket, Security groups, etc.

### 2. Build and Push Docker Image

Use the provided script:

```bash
cd infra
./build-and-push.sh
```

Or with a specific tag:

```bash
./build-and-push.sh v1.0.0
```

This script will:
- Login to ECR
- Build the Docker image
- Tag it properly
- Push to ECR

### 3. Deploy to EC2

If you're deploying for the first time or want to update the image:

```bash
# Deploy with latest tag (default)
terraform apply

# Or deploy a specific tag
terraform apply -var="docker_image_tag=v1.0.0"
```

The EC2 instance will:
- Pull the Docker image from ECR
- Run it as a systemd service
- Automatically restart on failure

## Updating the Application

To update the FTP server with new code:

```bash
# 1. Make your code changes

# 2. Build and push new image
cd infra
./build-and-push.sh v1.1.0

# 3. Update EC2 to use new image
terraform apply -var="docker_image_tag=v1.1.0"
```

Alternatively can also use the `teardown` and `startup` scripts.

This will recreate the EC2 instance with the new image.

## Some commands

### Use terraform data

`terraform output` returns a bunch of useful env vars and commands from the creation of the infra.

For example use `$(terraform output -raw ssh_command)` to ssh into the ec2 instance.