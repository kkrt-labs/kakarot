#!/usr/bin/env python3

import aws_cdk as cdk
from relayers_observer_service.relayers_observer_lambda_stack import (
    RelayerObserverLambdaStack,
)

app = cdk.App()
RelayerObserverLambdaStack(
    app,
    "RelayerObserverLambdaStack",
)

app.synth()
