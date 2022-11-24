import io
import logging
import os
import zipfile
from pathlib import Path

import pandas as pd
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    coverage_dir = Path("coverage")

    #%% Pull latest main artifacts
    response = requests.get(
        "https://api.github.com/repos/sayajin-labs/kakarot/actions/artifacts"
    )
    latest = sorted(
        [
            artifact
            for artifact in response.json()["artifacts"]
            if artifact["workflow_run"]["head_branch"] == "main"
        ],
        key=lambda artifact: artifact["updated_at"],
        reverse=True,
    )

    if not latest:
        logger.info("No artifacts found to compare against.")
        return

    response = requests.get(
        latest[0]["archive_download_url"],
        headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
    )

    z = zipfile.ZipFile(io.BytesIO(response.content))
    z.extractall(coverage_dir / "main")

    #%% Build aggregated stat for checking resources evolution
    resources_main = (
        pd.read_csv("./coverage/main/resources.csv")
        .assign(
            id=lambda df: pd.util.hash_pandas_object(
                df[["contract_name", "function_name", "args", "kwargs"]], index=False
            )
        )
        .drop_duplicates(["id"])
        .drop(["args", "kwargs", "id"], axis=1)
    )
    resources_branch = (
        pd.read_csv("./coverage/resources.csv")
        .assign(
            id=lambda df: pd.util.hash_pandas_object(
                df[["contract_name", "function_name", "args", "kwargs"]], index=False
            )
        )
        .drop_duplicates(["id"])
        .drop(["args", "kwargs", "id"], axis=1)
    )

    resources_change = (
        pd.concat(
            [resources_main.assign(ref="main"), resources_branch.assign(ref="branch")]
        )
        .groupby("ref")
        .agg("mean", numeric_only=True)
        .sort_index(ascending=False)
    )
    logger.info(resources_change)

    if not resources_change.diff().loc["branch"].round().le(0).all():
        pd.set_option("display.max_rows", 500)
        pd.set_option("display.max_columns", 500)
        pd.set_option("display.width", 1000)
        raise ValueError("Resources usage increase on average with this update")
    else:
        logger.info("Resources usage improved!")


if __name__ == "__main__":
    main()
