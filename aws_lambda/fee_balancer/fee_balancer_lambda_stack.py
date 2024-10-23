import os
import shutil

from aws_cdk import Duration, Stack
from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import aws_iam as iam
from aws_cdk import aws_lambda as _lambda
from constructs import Construct


class FeeBalancerLambdaStack(Stack):
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.build_lambda_func()

    def build_lambda_func(self):
        node_url = os.environ.get("NODE_URL")
        if node_url is None:
            raise ValueError("NODE_URL environment variable is not set")

        coinbase_contract_address = os.environ.get("COINBASE_CONTRACT_ADDRESS")
        if coinbase_contract_address is None:
            raise ValueError(
                "COINBASE_CONTRACT_ADDRESS environment variable is not set"
            )

        prev_total_balance = os.environ.get("PREV_TOTAL_BALANCE")
        if prev_total_balance is None:
            raise ValueError("PREV_TOTAL_BALANCE environment variable is not set")

        earning_percentage = os.environ.get("EARNING_PERCENTAGE")
        if earning_percentage is None:
            raise ValueError("EARNING_PERCENTAGE environment variable is not set")

        dest_dir = "./"
        shutil.copy(
            "../../kakarot_scripts/constants.py", os.path.join(dest_dir, "constants.py")
        )
        shutil.copy(
            "../../kakarot_scripts/utils/starknet.py",
            os.path.join(dest_dir, "starknet.py"),
        )
        shutil.copy("../../.env", os.path.join(dest_dir, ".env"))
        shutil.copytree(
            "../../build",
            os.path.join(dest_dir, "build"),
            dirs_exist_ok=True,
        )
        shutil.copytree(
            "../../deployments",
            os.path.join(dest_dir, "deployments"),
            dirs_exist_ok=True,
        )
        shutil.copytree(
            "../../kakarot_scripts/data",
            os.path.join(dest_dir, "data"),
            dirs_exist_ok=True,
        )
        self.prediction_lambda = _lambda.DockerImageFunction(
            scope=self,
            id="fee_balancer_lambda",
            function_name="fee_balancer",
            code=_lambda.DockerImageCode.from_image_asset(directory="."),
            environment={
                "NODE_URL": node_url,
                "COINBASE_CONTRACT_ADDRESS": coinbase_contract_address,
                "PREV_TOTAL_BALANCE": prev_total_balance,
                "EARNING_PERCENTAGE": earning_percentage,
            },
            environment_encryption=None,
            timeout=Duration.minutes(1),
        )

        secret_arns = [
            os.environ.get("RELAYERS_FUND_ACCOUNT_SECRET_ARN"),
            os.environ.get("ETH_COINBASE_OWNER_SECRET_ARN"),
        ]
        secret_arns = [arn for arn in secret_arns if arn is not None]

        self.prediction_lambda.add_to_role_policy(
            iam.PolicyStatement(
                actions=["secretsmanager:GetSecretValue"],
                resources=secret_arns,
            )
        )

        # param_arns = [
        #     os.environ.get("RELAYERS_PREV_TOTAL_BALANCE_PARAM_ARN"),
        #     os.environ.get("ACCOUNT_PREV_BALANCE_PARAM_ARN"),
        #     os.environ.get("EARNING_PERCENTAGE_PARAM_ARN"),
        # ]
        # param_arns = [arn for arn in param_arns if arn is not None]

        # self.prediction_lambda.add_to_role_policy(
        #     iam.PolicyStatement(
        #         actions=["ssm:GetParameter", "ssm:PutParameter"],
        #         resources=param_arns,
        #     )
        # )

        events.Rule(
            self,
            "ScheduleRule",
            schedule=events.Schedule.cron(minute="0/20"),
            targets=[targets.LambdaFunction(self.prediction_lambda)],
        )
