# Imports
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


def get_resources(
    coverage_dir: Path = Path("coverage"), base_branch_name: str = "main"
):
    # Pull latest main artifacts
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
        .loc[lambda df: df.name == "coverage"]
        .reindex(["head_branch", "updated_at", "archive_download_url"], axis=1)
        .sort_values(["head_branch", "updated_at"], ascending=False)
        .drop_duplicates(["head_branch"])
    )
    if base_branch_name not in artifacts.head_branch.tolist():
        logger.info(
            f"No artifacts found for base branch '{base_branch_name}'. Found\n{artifacts.head_branch.tolist()}"
        )

    for artifact in artifacts.to_dict("records"):
        response = requests.get(
            artifact["archive_download_url"],
            headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
        )

        z = zipfile.ZipFile(io.BytesIO(response.content))
        z.extractall(coverage_dir / artifact["head_branch"])

    return artifacts


def get_deployments(path: str = "deployments"):
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
        .loc[lambda df: df["head_branch"] == "main"]
        .loc[lambda df: df["name"] == "deployments"]
        .sort_values(["updated_at"], ascending=False)
        .archive_download_url
    )

    if artifacts.empty:
        raise ValueError(f"No deployment artifacts found for base branch main")

    response = requests.get(
        artifacts.tolist()[0],
        headers={"Authorization": f"Bearer {os.getenv('GITHUB_TOKEN')}"},
    )
    z = zipfile.ZipFile(io.BytesIO(response.content))
    z.extractall(path)
