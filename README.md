# AWS DevOps Agent Demo

This project demonstrates the implementation of AWS DevOps Agent (Frontier Agents) using AWS CDK. It deploys a complete infrastructure including IAM roles, EC2 instances in a private VPC, Lambda functions, and CloudWatch monitoring.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Setting Up the DevOps Agent](#setting-up-the-devops-agent)
- [Project Structure](#project-structure)
- [Demo: Testing AWS DevOps Agent Capabilities](#demo-testing-aws-devops-agent-capabilities)
  - [EC2 CPU Stress Test](#ec2-cpu-stress-test)
  - [Lambda Error Generation Test](#lambda-error-generation-test)
  - [Validate AWS DevOps Agent Detection](#validate-aws-devops-agent-detection)
- [Cleanup](#cleanup)
- [Useful Commands](#useful-commands)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Overview

The AWS DevOps Agent is an AI-powered service that helps with operational tasks across your AWS infrastructure. This demo creates a test environment to showcase its capabilities with monitored resources.

## Architecture

This CDK application deploys three main stacks:

### 1. IAM Stack

- **DevOps Agent Space Role**: IAM role for the AI DevOps agent with appropriate permissions
  - Assumes role by `aidevops.amazonaws.com` service principal
  - Includes `AIOpsAssistantPolicy` managed policy
  - Additional permissions for AWS Support, EKS, Synthetics, Route53, and Resource Explorer
- **EC2 Instance Role**: IAM role for EC2 instances with SSM access

### 2. EC2 Stack

- **VPC**: Private isolated VPC (10.0.0.0/16) across 2 AZs
- **VPC Endpoints**: SSM, SSM Messages, and EC2 Messages endpoints for private connectivity
- **EC2 Instance**: Amazon Linux 2023 t3.micro instance in private subnet
- **CloudWatch Alarm**: CPU utilization monitoring (threshold: 70%)
- **Security Groups**: Properly configured for VPC endpoint and EC2 access

### 3. Lambda Stack

- **Lambda Function**: Python 3.12 function for testing
- **CloudWatch Logs**: 1-week retention for function logs
- **CloudWatch Alarm**: Error monitoring for the function

## Prerequisites

- AWS CLI v2 installed and configured
- Node.js 18+ and npm installed
- AWS CDK CLI installed (`npm install -g aws-cdk`)
- AWS account with appropriate permissions
- AWS profile configured (or default credentials)

## Configuration

1. Create a configuration file at `config/config.json`:

```json
{
  "prefix": "your-project-prefix"
}
```

2. Create a tags file at `config/tags.json`:

```json
{
  "Environment": "demo",
  "Project": "aws-devops-agent",
  "ManagedBy": "CDK"
}
```

## Deployment

### Option 1: Using the deployment script (Recommended)

The deployment script automates the entire process including building, deploying CDK stacks, and optionally configuring the DevOps Agent Space.

```sh
# Make the script executable
chmod +x deploy.sh

# Run with AWS profile as parameter
./deploy.sh YOUR_PROFILE

# Or using environment variable
PROFILE=YOUR_PROFILE ./deploy.sh

# Or run interactively (will prompt for profile)
./deploy.sh
```

The script will:

1. Install npm dependencies
2. Build the TypeScript code
3. Attempt AWS SSO login (if configured)
4. Deploy all CDK stacks
5. Optionally create and configure the DevOps Agent Space
6. Save the Agent Space ID to `.agent-space-id` file for later use

### Option 2: Manual deployment with CDK

```sh
# Install dependencies
npm install

# Build the TypeScript code
npm run build

# Deploy all stacks
cdk deploy --all --require-approval never

# Or with a specific AWS profile
cdk deploy --profile YOUR_PROFILE --all --require-approval never
```

## Setting Up the DevOps Agent

**Note:** If you used the deployment script (`deploy.sh`), you can skip this section as it offers to configure the DevOps Agent automatically.

If you deployed manually or want to configure the Agent Space separately, follow these steps:

### 1. Create Agent Space

```sh
aws devopsagent create-agent-space \
  --name "YOUR_AGENT_NAME" \
  --description "DevOps Agent Space with test environment" \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1 \
  --profile YOUR_PROFILE
```

Note the `agent-space-id` from the output for the next steps.

### 2. Associate AWS Service

```sh
aws devopsagent associate-service \
  --agent-space-id "YOUR_AGENT_SPACE_ID" \
  --service-id aws \
  --configuration '{"aws": {"assumableRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_PREFIX-space-role", "accountId": "YOUR_ACCOUNT_ID", "accountType": "monitor", "resources": []}}' \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1 \
  --profile YOUR_PROFILE
```

### 3. Enable Operator App

```sh
aws devopsagent enable-operator-app \
  --agent-space-id "YOUR_AGENT_SPACE_ID" \
  --auth-flow iam \
  --operator-app-role-arn "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_PREFIX-space-role" \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1 \
  --profile YOUR_PROFILE
```

## Project Structure

```
.
├── bin/
│   └── main.ts                 # CDK app entry point
├── lib/
│   ├── iam-stack.ts           # IAM roles and policies
│   ├── ec2-stack.ts           # VPC, EC2, and networking
│   └── lambda-stack.ts        # Lambda function and monitoring
├── scripts/
│   ├── user-data.sh           # EC2 instance initialization script
│   └── lambda_function/       # Lambda function code
├── config/
│   ├── config.json            # Project configuration
│   └── tags.json              # Resource tags
├── cdk.json                   # CDK configuration
├── package.json               # Node.js dependencies
└── README.md                  # This file
```

## Cleanup

To avoid ongoing charges, destroy the resources when done.

### Option 1: Using the destroy script (Recommended)

The destroy script automates the cleanup process including deleting the DevOps Agent Space and all CDK stacks.

```sh
# Make the script executable
chmod +x destroy.sh

# Run with AWS profile as parameter
./destroy.sh YOUR_PROFILE

# Or using environment variable
PROFILE=YOUR_PROFILE ./destroy.sh

# Or run interactively (will prompt for profile)
./destroy.sh
```

The script will:

1. Prompt for confirmation before proceeding
2. Delete the DevOps Agent Space (if `.agent-space-id` file exists)
3. Destroy all CDK stacks
4. Clean up the `.agent-space-id` file

### Option 2: Manual cleanup

```sh
# Delete the DevOps Agent Space (if you created one)
aws devopsagent delete-agent-space \
  --agent-space-id "YOUR_AGENT_SPACE_ID" \
  --endpoint-url "https://api.prod.cp.aidevops.us-east-1.api.aws" \
  --region us-east-1 \
  --profile YOUR_PROFILE

# Destroy CDK stacks
cdk destroy --all --profile YOUR_PROFILE
```

## Demo: Testing AWS DevOps Agent Capabilities

Once deployed, you can test the AWS DevOps Agent's ability to detect and investigate issues using the following scenarios.

### EC2 CPU Stress Test

The EC2 instance includes a pre-configured CPU stress test script. The beauty of using SSM instead of SSH is the enhanced security and simplified access.

#### Step 1: Connect to EC2 Instance

First, get your EC2 instance ID:

```sh
# Get the EC2 instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=demo-devops-agent-ec2-instace" \
           "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text \
  --profile YOUR_PROFILE)

echo "Instance ID: $INSTANCE_ID"
```

Connect to the instance via SSM (no SSH keys needed):

```sh
aws ssm start-session --target $INSTANCE_ID --profile YOUR_PROFILE
```

#### Step 2: Run CPU Stress Test

Once connected to the instance:

```sh
# Switch to root and navigate to home directory
sudo su
cd /home/ec2-user

# List available test files
ls
# Output: auto-shutdown.log  auto-shutdown.sh  cpu-stress-test.sh  setup-complete.txt

# Execute CPU stress test
./cpu-stress-test.sh
```

#### Expected Output:

```
Starting YOUR_PREFIX DevOps Agent CPU Stress Test
Time: Wed Dec 17 22:14:30 UTC 2025
Instance: i-0abcd1234efgh5678

CPU Cores: 2

Starting stress test (5 minutes)...
This will generate >70% CPU usage to trigger CloudWatch alarm

Starting CPU load processes...
Started CPU load process 1 (PID: 1234)
Started CPU load process 2 (PID: 1235)

CPU load processes started for 5 minutes
Check CloudWatch for alarm trigger in 3-5 minutes
```

The script automatically:

- Detects CPU cores (2 cores on t3.micro)
- Generates 100% CPU load for 5 minutes
- Auto-cleans up processes after completion
- Triggers CloudWatch alarm when CPU >70%

### Lambda Error Generation Test

The Lambda function can be tested to generate errors that the DevOps Agent will detect and investigate.

#### Step 1: Create Test Payload

```sh
# Create test payload file
cat > test-payload.json << EOF
{
  "test": "AWS DevOps Agent validation",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
```

#### Step 2: Invoke Lambda with Test Payload

```sh
# Generate errors (base64 encoding is crucial)
PAYLOAD=$(cat test-payload.json | base64)

aws lambda invoke \
    --function-name YOUR_PREFIX-lambda-function \
    --payload "$PAYLOAD" \
    --profile YOUR_PROFILE \
    response.json

# Check the response
cat response.json
```

#### Step 3: Generate Multiple Errors

To trigger the CloudWatch alarm, invoke the function multiple times:

```sh
# Generate 5 errors to trigger alarm
for i in {1..5}; do
  echo "Invoking Lambda (attempt $i)..."
  PAYLOAD=$(cat test-payload.json | base64)
  aws lambda invoke \
      --function-name YOUR_PREFIX-lambda-function \
      --payload "$PAYLOAD" \
      --profile YOUR_PROFILE \
      response-$i.json
  sleep 2
done
```

### Validate AWS DevOps Agent Detection

After running the tests, open the AWS DevOps Agent web application to watch the investigation unfold in real-time.

#### For EC2 CPU Issues:

The agent will:

- ✅ Identify the EC2 instance experiencing high CPU
- ✅ Correlate CloudWatch metrics with instance metadata
- ✅ Analyze the stress test workload pattern
- ✅ Provide recommendations for monitoring and auto-scaling

#### For Lambda Error Spikes:

The agent will:

- ✅ Detect the Lambda error rate increase
- ✅ Examine function logs and error patterns
- ✅ Identify the intentional test exceptions
- ✅ Suggest error handling improvements and monitoring enhancements

### Monitoring Alarms

You can monitor the alarms status using AWS CLI:

```sh
# Check EC2 CPU alarm status
aws cloudwatch describe-alarms \
  --alarm-names "YOUR_PREFIX-ec2-cpu-alarm" \
  --profile YOUR_PROFILE

# Check Lambda error alarm status
aws cloudwatch describe-alarms \
  --alarm-names "YOUR_PREFIX-lambda-error-alarm" \
  --profile YOUR_PROFILE

# Get alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name "YOUR_PREFIX-ec2-cpu-alarm" \
  --max-records 5 \
  --profile YOUR_PROFILE
```

## Useful Commands

- `npm run build` - Compile TypeScript to JavaScript
- `npm run watch` - Watch for changes and compile
- `npm test` - Run Jest tests
- `cdk diff` - Compare deployed stack with current state
- `cdk synth` - Emit the synthesized CloudFormation template

## Troubleshooting

### EC2 Instance Connection

The EC2 instance is in a private subnet without internet access. Use AWS Systems Manager Session Manager to connect:

```sh
aws ssm start-session --target INSTANCE_ID --profile YOUR_PROFILE
```

### Lambda Function Logs

View Lambda function logs:

```sh
aws logs tail /aws/lambda/YOUR_PREFIX-lambda-function-logs --follow --profile YOUR_PROFILE
```

### CloudWatch Alarms

Monitor alarms in the CloudWatch console or via CLI:

```sh
aws cloudwatch describe-alarms --profile YOUR_PROFILE
```

## License

This project is provided as a demonstration and educational resource.
