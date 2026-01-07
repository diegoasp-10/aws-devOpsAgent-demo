import * as cdk from "aws-cdk-lib";
import * as fs from 'fs';
import * as path from 'path';
import * as lambda from "aws-cdk-lib/aws-lambda";
import { Construct } from "constructs";

export interface LambdaStackProps extends cdk.StackProps {
    prefix: string;
}

export class LambdaStack extends cdk.Stack {
    constructor(scope: Construct, id: string, props: LambdaStackProps) {
        super(scope, id, props);

        const lambdaFunction = new lambda.Function(
            this,
            `${props.prefix}-lambda-function`,
            {
                runtime: lambda.Runtime.PYTHON_3_12,
                functionName: `${props.prefix}-lambda-function`,
                handler: "index.lambda_handler",
                code: lambda.Code.fromAsset(
                    path.join(__dirname, '../scripts/lambda_function')
                ),
                logGroup: new cdk.aws_logs.LogGroup(this, `${props.prefix}-lambda-function-logs`, {
                    logGroupName: `/aws/lambda/${props.prefix}-lambda-function-logs`,
                    retention: cdk.aws_logs.RetentionDays.ONE_WEEK,
                    removalPolicy: cdk.RemovalPolicy.DESTROY
                }),
            }
        );

        new cdk.aws_cloudwatch.Alarm(this, `${props.prefix}-lambda-error-alarm`, {
            alarmName: `${props.prefix}-lambda-error-alarm`,
            metric: lambdaFunction.metricErrors({
                statistic: 'Sum',
                period: cdk.Duration.minutes(5),
            }),
            threshold: 0,
            comparisonOperator: cdk.aws_cloudwatch.ComparisonOperator.GREATER_THAN_THRESHOLD,
            evaluationPeriods: 1,
        });

    }
}
