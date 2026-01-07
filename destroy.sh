#!/bin/bash

# AWS DevOps Agent Destroy Script
# Usage: ./destroy.sh [PROFILE_NAME]
# Or: PROFILE=your-profile ./destroy.sh

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
    exit 1
fi

# Extract prefix from config.json
PREFIX=$(cat $CONFIG_FILE | grep -o '"prefix"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"prefix"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

if [ -z "$PREFIX" ]; then
    print_error "Unable to read 'prefix' from $CONFIG_FILE"
    exit 1
fi

print_info "Project prefix: $PREFIX"

# Warning message
echo ""
print_warning "========================================="
print_warning "WARNING: This will destroy ALL resources!"
print_warning "========================================="
echo ""
echo "This will delete:"
echo "  - IAM Stack: ${PREFIX}-iam-stack"
echo "  - EC2 Stack: ${PREFIX}-ec2-stack"
echo "  - Lambda Stack: ${PREFIX}-lambda-stack"
echo "  - DevOps Agent Space (if exists)"
echo ""

read -p "Are you sure you want to continue? Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    print_info "Destruction cancelled."
    exit 0
fi

# Check if Agent Space ID exists
AGENT_SPACE_ID=""
if [ -f ".agent-space-id" ]; then
    AGENT_SPACE_ID=$(cat .agent-space-id)
    print_info "Found Agent Space ID: $AGENT_SPACE_ID"
fi

# Delete Agent Space if it exists
if [ -n "$AGENT_SPACE_ID" ]; then
    print_info "Deleting DevOps Agent Space..."

    ENDPOINT_URL="https://api.prod.cp.aidevops.us-east-1.api.aws"
    REGION="us-east-1"

    # Try to delete the agent space
    if aws devopsagent delete-agent-space \
        --agent-space-id "$AGENT_SPACE_ID" \
        --endpoint-url "$ENDPOINT_URL" \
        --region $REGION \
        --profile $PROFILE 2>/dev/null; then
        print_info "Agent Space deleted successfully"
        rm -f .agent-space-id
    else
        print_warning "Failed to delete Agent Space or it doesn't exist"
        print_warning "You may need to delete it manually from the AWS Console"
    fi
else
    print_warning "No Agent Space ID found. Skipping Agent Space deletion."
fi

# Destroy CDK stacks
print_info "Destroying CDK stacks..."
cdk destroy --profile $PROFILE --all --force

# Summary
echo ""
echo "========================================="
print_info "Destruction completed!"
echo "========================================="
echo ""
print_info "All resources have been removed."

# Check for any remaining files
if [ -f ".agent-space-id" ]; then
    rm -f .agent-space-id
    print_info "Cleaned up .agent-space-id file"
fi

echo ""
print_info "Cleanup complete!"
echo ""
