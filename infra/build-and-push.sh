#!/bin/bash
set -e

# Script to build and push Docker image to ECR
# Usage: ./build-and-push.sh [tag] [aws-profile]
# Example: ./build-and-push.sh latest my-sso-profile

# Get the tag from argument or use "latest"
TAG="${1:-latest}"
PROFILE="${2:-${AWS_PROFILE}}"

echo "========================================"
echo "Building and Pushing FTP Server to ECR"
echo "========================================"

# Check if we're in the infra directory
if [ ! -f "terraform.tfvars" ]; then
    echo "Error: Please run this script from the infra directory"
    exit 1
fi

# Set up AWS profile flag if specified
if [ -n "$PROFILE" ]; then
    AWS_CMD="aws --profile $PROFILE"
    echo "Using AWS Profile: $PROFILE"
else
    AWS_CMD="aws"
    echo "Using default AWS credentials"
fi
echo ""

# Check if we can access AWS
echo "Checking AWS credentials..."
if ! $AWS_CMD sts get-caller-identity &>/dev/null; then
    echo ""
    echo "Error: Unable to authenticate with AWS"
    echo ""
    echo "If using SSO, make sure you're logged in:"
    echo "  aws sso login --profile YOUR_PROFILE"
    echo ""
    echo "Then run this script with your profile:"
    echo "  ./build-and-push.sh latest YOUR_PROFILE"
    echo ""
    echo "Or set the AWS_PROFILE environment variable:"
    echo "  export AWS_PROFILE=YOUR_PROFILE"
    echo "  ./build-and-push.sh latest"
    exit 1
fi

ACCOUNT_ID=$($AWS_CMD sts get-caller-identity --query Account --output text)
echo "✓ Authenticated as AWS Account: $ACCOUNT_ID"
echo ""

# Get ECR repository URL from Terraform output
echo "Getting ECR repository URL from Terraform..."
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null)

if [ -z "$ECR_REPO" ]; then
    echo "Error: Could not get ECR repository URL from Terraform"
    echo "Make sure you've run 'terraform apply' first"
    exit 1
fi

# Get AWS region
AWS_REGION=$(terraform output -json | jq -r '.ecr_repository_url.value' | cut -d'.' -f4)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=$(grep 'aws_region' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
fi

echo "ECR Repository: $ECR_REPO"
echo "AWS Region: $AWS_REGION"
echo "Tag: $TAG"
echo ""

# Login to ECR
echo "Logging in to ECR..."
$AWS_CMD ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO

# Build Docker image
echo ""
echo "Building Docker image..."
cd ..  # Go to project root
docker build -t ftp-server:$TAG -f Dockerfile .

# Tag for ECR
echo ""
echo "Tagging image for ECR..."
docker tag ftp-server:$TAG $ECR_REPO:$TAG

# Push to ECR
echo ""
echo "Pushing image to ECR..."
docker push $ECR_REPO:$TAG

echo ""
echo "========================================"
echo "✓ Successfully pushed to ECR!"
echo "  Image: $ECR_REPO:$TAG"
echo "========================================"
echo ""
echo "To deploy this image, run:"
if [ -n "$PROFILE" ]; then
    echo "  cd infra"
    echo "  AWS_PROFILE=$PROFILE terraform apply -var=\"docker_image_tag=$TAG\""
else
    echo "  cd infra"
    echo "  terraform apply -var=\"docker_image_tag=$TAG\""
fi
