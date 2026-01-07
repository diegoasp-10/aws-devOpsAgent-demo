import * as cdk from 'aws-cdk-lib';
import * as fs from 'fs';
import * as path from 'path';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export interface EC2StackProps extends cdk.StackProps {
	prefix: string;
	ec2Role: cdk.aws_iam.Role;
}

export class EC2Stack extends cdk.Stack {
	constructor(scope: Construct, id: string, props: EC2StackProps) {
		super(scope, id, props);

		const vpc = new ec2.Vpc(this, `${props.prefix}-vpc`, {
			vpcName: `${props.prefix}-vpc`,
			ipAddresses: ec2.IpAddresses.cidr('10.0.0.0/16'),
			enableDnsHostnames: true,
			enableDnsSupport: true,
			maxAzs: 2,
			subnetConfiguration: [
				{
					name: 'Private',
					subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
					cidrMask: 24,
				},
			],
		});

		const vpcSg = new ec2.SecurityGroup(this, `${props.prefix}-vpc-sg`, {
			securityGroupName: `${props.prefix}-sg`,
			vpc: vpc,
			description: 'Security group for VPC endpoints',
			allowAllOutbound: true,
		});

		vpcSg.addIngressRule(
			ec2.Peer.ipv4(vpc.vpcCidrBlock),
			ec2.Port.tcp(443),
			'Allow HTTPS from VPC'
		);

		vpc.addInterfaceEndpoint(`${props.prefix}-ssm-endpoint`, {
			service: ec2.InterfaceVpcEndpointAwsService.SSM,
			securityGroups: [vpcSg],
		});

		vpc.addInterfaceEndpoint(`${props.prefix}-ssm-message-endpoint`, {
			service: ec2.InterfaceVpcEndpointAwsService.SSM_MESSAGES,
			securityGroups: [vpcSg],
		});

		vpc.addInterfaceEndpoint(`${props.prefix}-ec2-message-endpoint`, {
			service: ec2.InterfaceVpcEndpointAwsService.EC2_MESSAGES,
			securityGroups: [vpcSg],
		});

		vpc.addGatewayEndpoint(`${props.prefix}-s3-endpoint`, {
			service: ec2.GatewayVpcEndpointAwsService.S3,
			subnets: [{ subnetType: ec2.SubnetType.PRIVATE_ISOLATED }],
		});

		const ec2Sg = new ec2.SecurityGroup(this, `${props.prefix}-ec2-sg`, {
			securityGroupName: `${props.prefix}-ec2-sg`,
			vpc: vpc,
			description: 'Security group for test EC2 instance',
			allowAllOutbound: true,
		});

		const ec2UserData = ec2.UserData.forLinux();
		const ec2UserDataScript = fs.readFileSync(
			path.join(__dirname, '../scripts/user-data.sh'),
			'utf-8'
		);
		ec2UserData.addCommands(
			ec2UserDataScript
		)

		const ec2Instance = new ec2.Instance(this, `${props.prefix}-ec2-instace`, {
			instanceName: `${props.prefix}-ec2-instace`,
			vpc: vpc,
			vpcSubnets: {
				subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
			},
			instanceType: ec2.InstanceType.of(ec2.InstanceClass.T3, ec2.InstanceSize.MICRO),
			machineImage: ec2.MachineImage.latestAmazonLinux2023({
				cpuType: ec2.AmazonLinuxCpuType.X86_64,
			}),
			role: props.ec2Role,
			securityGroup: ec2Sg,
			userData: ec2UserData,
		});

		new cdk.aws_cloudwatch.Alarm(this, `${props.prefix}-ec2-cpu-alarm`, {
			alarmName: `${props.prefix}-ec2-cpu-alarm`,
			metric: new cdk.aws_cloudwatch.Metric({
				namespace: 'AWS/EC2',
				metricName: 'CPUUtilization',
				dimensionsMap: {
					InstanceId: ec2Instance.instanceId,
				},
				statistic: 'Average',
				period: cdk.Duration.minutes(5),
			}),
			threshold: 70,
			comparisonOperator: cdk.aws_cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
			evaluationPeriods: 1,
		});
	}
}