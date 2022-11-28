import io
import logging
import os
import zipfile
from pathlib import Path

import pandas as pd
import requests
from dotenv import load_dotenv

load_dotenv()
pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 10)
pd.set_option("display.width", 1000)
pd.set_option("max_colwidth", 400)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    coverage_dir = Path("coverage")
    base_branch_name = "main"

    #%% Pull latest main artifacts
    response = requests.get(
        "https://api.github.com/repos/sayajin-labs/kakarot/actions/artifacts"
    )
    artifacts = (
        pd.DataFrame(
            [
                {**artifact["workflow_run"], **artifact}
                for artifact in response.json()["artifacts"]
            ]
        )
        .reindex(["head_branch", "updated_at", "archive_download_url"], axis=1)
        .sort_values(["head_branch", "updated_at"], ascending=False)
        .drop_duplicates(["head_branch"])
    )
    if base_branch_name not in artifacts.head_branch.tolist():
        logger.info(
            f"No artifacts found for base branch '{base_branch_name}'. Found\n{artifacts.head_branch.tolist()}"
        )
        return

    for artifact in artifacts.to_dict("records"):
        response = requests.get(
            artifact["archive_download_url"],
            headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
        )

        z = zipfile.ZipFile(io.BytesIO(response.content))
        z.extractall(coverage_dir / artifact["head_branch"])

    #%% Build aggregated stat for checking resources evolution
    resources = [
        (
            pd.read_csv(coverage_dir / artifact["head_branch"] / "resources.csv")
            .assign(
                id=lambda df: pd.util.hash_pandas_object(
                    df[["contract_name", "function_name", "args", "kwargs"]],
                    index=False,
                ),
                head_branch=artifact["head_branch"],
            )
            .drop_duplicates(["id"])
            .drop(["contract_name", "function_name", "args", "kwargs"], axis=1)
        )
        for artifact in artifacts.to_dict("records")
    ]
    if (coverage_dir / "resources.csv").exists():
        resources.append(
            (
                pd.read_csv(coverage_dir / "resources.csv")
                .assign(
                    id=lambda df: pd.util.hash_pandas_object(
                        df[["contract_name", "function_name", "args", "kwargs"]],
                        index=False,
                    ),
                    head_branch="local",
                )
                .drop_duplicates(["id"])
                .drop(["contract_name", "function_name", "args", "kwargs"], axis=1)
            )
        )
    else:
        logger.info("No local resources found to compare against")

    resources_change = (
        pd.concat(resources)
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
    logger.info(f"Resources summary:\n{resources_change}")

    if "local" in resources_change.index:
        ratio = resources_change.loc["local"] / resources_change.loc[base_branch_name]
        if not ratio.le(1).all():
            raise ValueError("Resources usage increase on average with this update")
        else:
            if ratio.eq(1).all():
                logger.info("No resources usage modification")
            else:
                logger.info("Resources usage improved!")


if __name__ == "__main__":
    main()
