#!/bin/bash

# AWS DevOps Agent Deployment Script
# Usage: ./deploy.sh [PROFILE_NAME]
# Or: PROFILE=your-profile ./deploy.sh

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get AWS profile from parameter, environment variable, or prompt
if [ -n "$1" ]; then
    PROFILE="$1"
elif [ -n "$PROFILE" ]; then
    PROFILE="$PROFILE"
else
    print_warning "No AWS profile specified."
    read -p "Enter AWS profile name (or press Enter for default): " PROFILE
    if [ -z "$PROFILE" ]; then
        PROFILE="default"
    fi
fi

print_info "Using AWS profile: $PROFILE"

# Read configuration
CONFIG_FILE="./config/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found: $CONFIG_FILE"
    print_info "Please create config/config.json with the required configuration."
    exit 1
fi

# Extract prefix from config.json
PREFIX=$(cat $CONFIG_FILE | grep -o '"prefix"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"prefix"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$PREFIX" ]; then
    print_error "Unable to read 'prefix' from $CONFIG_FILE"
    exit 1
fi

print_info "Project prefix: $PREFIX"

# Install dependencies
print_info "Installing dependencies..."
npm install

# Login to AWS SSO (if using SSO)
print_info "Attempting AWS SSO login..."
if aws sso login --profile $PROFILE 2>/dev/null; then
    print_info "SSO login successful"
else
    print_warning "SSO login failed or not configured. Proceeding with existing credentials..."
fi

# Get AWS Account ID
print_info "Retrieving AWS Account ID..."
ACCOUNT_ID=$(aws sts get-caller-identity --profile $PROFILE --query "Account" --output text)
if [ -z "$ACCOUNT_ID" ]; then
    print_error "Failed to retrieve AWS Account ID. Please check your credentials."
    exit 1
fi
print_info "Account ID: $ACCOUNT_ID"

# Deploy CDK stacks
print_info "Deploying CDK stacks..."
cdk deploy --profile $PROFILE --all --require-approval never

# Prompt user if they want to create DevOps Agent Space
read -p "Do you want to create the DevOps Agent Space? (y/n): " CREATE_AGENT
if [ "$CREATE_AGENT" != "y" ] && [ "$CREATE_AGENT" != "Y" ]; then
    print_info "Skipping DevOps Agent Space creation."
    print_info "Deployment completed successfully!"
    exit 0
fi

# Agent Space configuration
read -p "Enter Agent Space name (default: ${PREFIX}-agent-space): " AGENT_NAME
AGENT_NAME=${AGENT_NAME:-"${PREFIX}-agent-space"}

ENDPOINT_URL="https://api.prod.cp.aidevops.us-east-1.api.aws"
REGION="us-east-1"

# Create Agent Space
print_info "Creating DevOps Agent Space: $AGENT_NAME"
AGENT_SPACE_ID=$(aws devopsagent create-agent-space \
  --name "$AGENT_NAME" \
  --description "DevOps Agent Space for ${PREFIX} with test environment" \
  --endpoint-url "$ENDPOINT_URL" \
  --region $REGION \
  --profile $PROFILE \
  --query "agentSpace.agentSpaceId" \
  --output text 2>/dev/null)

if [ -z "$AGENT_SPACE_ID" ]; then
    print_error "Failed to create Agent Space. Please check your permissions and endpoint URL."
    exit 1
fi

print_info "Agent Space ID: $AGENT_SPACE_ID"

# Save Agent Space ID to file for later use
echo "$AGENT_SPACE_ID" > .agent-space-id
print_info "Agent Space ID saved to .agent-space-id"

# Associate AWS Service
print_info "Associating AWS service with Agent Space..."
aws devopsagent associate-service \
  --agent-space-id "$AGENT_SPACE_ID" \
  --service-id aws \
  --configuration "{\"aws\": {\"assumableRoleArn\": \"arn:aws:iam::${ACCOUNT_ID}:role/${PREFIX}-space-role\", \"accountId\": \"${ACCOUNT_ID}\", \"accountType\": \"monitor\", \"resources\": []}}" \
  --endpoint-url "$ENDPOINT_URL" \
  --region $REGION \
  --profile $PROFILE

print_info "AWS service associated successfully"

# Enable Operator App
print_info "Enabling Operator App..."
aws devopsagent enable-operator-app \
  --agent-space-id "$AGENT_SPACE_ID" \
  --auth-flow iam \
  --operator-app-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${PREFIX}-space-role" \
  --endpoint-url "$ENDPOINT_URL" \
  --region $REGION \
  --profile $PROFILE

print_info "Operator App enabled successfully"

# Summary
echo ""
echo "========================================="
print_info "Deployment completed successfully!"
echo "========================================="
echo ""
echo "Resources deployed:"
echo "  - IAM Stack: ${PREFIX}-iam-stack"
echo "  - EC2 Stack: ${PREFIX}-ec2-stack"
echo "  - Lambda Stack: ${PREFIX}-lambda-stack"
echo ""
echo "DevOps Agent:"
echo "  - Agent Space ID: $AGENT_SPACE_ID"
echo "  - Agent Name: $AGENT_NAME"
echo ""
print_info "You can now use the AWS DevOps Agent to manage your infrastructure!"
echo ""
