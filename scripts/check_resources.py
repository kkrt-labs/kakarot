# Imports
import logging
from pathlib import Path

import pandas as pd

from scripts.artifacts import get_resources

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 10)
pd.set_option("display.width", 1000)
pd.set_option("max_colwidth", 400)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    # Script constants
    coverage_dir = Path("coverage")
    base_branch_name = "main"
    current_name = "local"

    artifacts = get_resources(coverage_dir, base_branch_name)

    #  Build aggregated stat for checking resources evolution
    resources = [
        (
            pd.read_csv(
                coverage_dir / artifact["head_branch"] / "resources.csv"
            ).assign(head_branch=artifact["head_branch"])
        )
        for artifact in artifacts.to_dict("records")
    ]
    if (coverage_dir / "resources.csv").exists():
        resources.append(
            pd.read_csv(coverage_dir / "resources.csv").assign(head_branch=current_name)
        )
    else:
        logger.info("No local resources found to compare against")

    all_resources = (
        pd.concat(resources)
        .assign(
            id=lambda df: pd.util.hash_pandas_object(
                df[["contract_name", "function_name", "args", "kwargs"]],
                index=False,
            )
        )
        .drop_duplicates(["head_branch", "id"])
        .loc[lambda df: ~df.contract_name.str.contains("test")]  # type: ignore
        .loc[lambda df: ~df.function_name.str.contains("test")]
    )
    resources_summary = (
        all_resources.drop(["contract_name", "function_name", "args", "kwargs"], axis=1)
        .groupby("id")
        .filter(lambda group: len(group) == len(resources))
        .drop(["id"], axis=1)
        .groupby(["head_branch"])
        .agg("mean", numeric_only=True)
        .reset_index()
        .merge(artifacts[["head_branch", "updated_at"]], on="head_branch", how="left")
        .fillna({"updated_at": pd.Timestamp.today()})
        .astype({"updated_at": "datetime64"})
        .sort_values("updated_at", ascending=False)
        .drop("updated_at", axis=1)
        .set_index("head_branch")
        .round(2)
    )
    logger.info(f"Resources summary:\n{resources_summary}")

    # Compare local test run with base branch
    if ({current_name, base_branch_name}).issubset(set(all_resources.head_branch)):
        tests_with_diff = (
            all_resources.loc[
                lambda df: df.head_branch.isin([current_name, base_branch_name])
            ]  # type: ignore
            .groupby("id")
            .filter(
                lambda group: len(group) == 2
                and len(
                    group.drop(["head_branch", "context"], axis=1).drop_duplicates()
                )
                == 2
            )
            .drop(["context", "args", "kwargs"], axis=1)
        )
        if len(tests_with_diff) == 0:
            logger.info("No resources usage modification")
            return

        detailed_diff = (
            tests_with_diff.groupby(
                ["id", "contract_name", "function_name"], group_keys=True
            )
            .apply(
                lambda group: group.set_index("head_branch")
                .reindex([base_branch_name, current_name])
                .diff()
            )
            .xs(current_name, axis=0, level=3)
            .reset_index(level=0, drop=True)
            .loc[lambda df: df.any(axis=1)]
            .sort_index(level=["contract_name", "function_name"])
        )

        # TODO: use actual formula from https://docs.starknet.io/documentation/architecture_and_concepts/Fees/fee-mechanism
        logger.info(f"Detailed difference:\n{detailed_diff}")
        usage_improved = detailed_diff.agg("mean").le(10).all()
        if not usage_improved:
            raise ValueError("Resources usage increase on average with this update")
        else:
            logger.info("Resources usage improved!")


if __name__ == "__main__":
    main()
