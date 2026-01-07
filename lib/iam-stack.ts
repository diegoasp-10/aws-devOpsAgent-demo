import * as cdk from "aws-cdk-lib";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

export interface IAMStackProps extends cdk.StackProps {
    prefix: string;
}

export class IAMStack extends cdk.Stack {
    public readonly ec2Role;
    constructor(scope: Construct, id: string, props: IAMStackProps) {
        super(scope, id, props);

        const devOpsAgentSpaceRole = new iam.Role(
            this,
            `${props.prefix}-role`,
            {
                roleName: `${props.prefix}-space-role`,
                assumedBy: new iam.ServicePrincipal("aidevops.amazonaws.com", {
                    conditions: {
                        StringEquals: {
                            "aws:SourceAccount": this.account,
                        },
                        ArnLike: {
                            "aws:SourceArn": `arn:aws:aidevops:us-east-1:${this.account}:agentspace/*`,
                        },
                    },
                }),
                managedPolicies: [
                    iam.ManagedPolicy.fromAwsManagedPolicyName("AIOpsAssistantIncidentReportPolicy"),
                    iam.ManagedPolicy.fromAwsManagedPolicyName("AIOpsAssistantPolicy"),
                    iam.ManagedPolicy.fromAwsManagedPolicyName("AIOpsConsoleAdminPolicy"),
                    iam.ManagedPolicy.fromAwsManagedPolicyName("AIOpsOperatorAccess")
                ],
            }
        );

        devOpsAgentSpaceRole.addToPolicy(
            new iam.PolicyStatement({
                sid: "AllowExpandedAIOpsAssistantPolicy",
                effect: iam.Effect.ALLOW,
                actions: [
                    "aidevops:*",
                    "eks:*",
                    "synthetics:*",
                    "route53:*",
                    "resource-explorer-2:*",
                ],
                resources: ["*"],
            })
        );

        this.ec2Role = new iam.Role(this, 'EC2InstanceRole', {
            assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
            managedPolicies: [
                iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'),
            ],
        });
    }
}
