#!/usr/bin/env python3

import aws_cdk as cdk
from fee_balancer_lambda_stack import FeeBalancerLambdaStack

app = cdk.App()
FeeBalancerLambdaStack(app, "FeeBalancerLambdaStack")

app.synth()
