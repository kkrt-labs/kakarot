import os
import shutil

from aws_cdk import Duration, Stack
from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import aws_iam as iam
from aws_cdk import aws_lambda as _lambda
from constructs import Construct


class RelayerObserverLambdaStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.build_lambda_func()

    def build_lambda_func(self):
        dest_dir = "relayers_observer_service/relayers_observer_lambda"
        shutil.copy("../../constants.py", os.path.join(dest_dir, "constants.py"))
        shutil.copy("../../utils/starknet.py", os.path.join(dest_dir, "starknet.py"))
        shutil.copy("../../../.env", os.path.join(dest_dir, ".env"))
        shutil.copytree(
            "../../../build", os.path.join(dest_dir, "build"), dirs_exist_ok=True
        )
        shutil.copytree(
            "../../../deployments",
            os.path.join(dest_dir, "deployments"),
            dirs_exist_ok=True,
        )
        shutil.copytree(
            "../../data", os.path.join(dest_dir, "data"), dirs_exist_ok=True
        )
        self.prediction_lambda = _lambda.DockerImageFunction(
            scope=self,
            id="relayers_observer_lambda",
            function_name="relayers_observer",
            code=_lambda.DockerImageCode.from_image_asset(
                directory="relayers_observer_service/relayers_observer_lambda"
            ),
            environment_encryption=None,
            timeout=Duration.minutes(1),
        )

        self.prediction_lambda.add_to_role_policy(
            iam.PolicyStatement(
                actions=["secretsmanager:GetSecretValue"],
                resources=[os.environ.get("RELAYERS_FUND_ACCOUNT_SECRET_ARN")],
            )
        )

        events.Rule(
            self,
            "ScheduleRule",
            schedule=events.Schedule.cron(minute="0/20"),
            targets=[targets.LambdaFunction(self.prediction_lambda)],
        )
