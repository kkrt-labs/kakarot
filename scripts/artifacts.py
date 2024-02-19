# Imports
import io
import logging
import os
import re
import zipfile
from pathlib import Path
from typing import Union

import matplotlib.pyplot as plt
import pandas as pd
import requests
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def pull_and_plot_ef_tests(name: Union[str, Path] = Path("logs")):
    # Pull latest main artifacts
    response = requests.get(
        "https://api.github.com/repos/kkrt-labs/kakarot/actions/workflows/ci.yml/runs?branch=cw/run-all&per_page=100"
    )
    logs = (
        pd.DataFrame(response.json()["workflow_runs"])[["created_at", "logs_url"]]
        .astype({"created_at": "datetime64"})
        .sort_values("created_at", ascending=False)
    )

    results = []
    for log in logs.to_dict("records"):
        logger.info(f"Fetching logs for {log['created_at']}")
        response = requests.get(
            log["logs_url"],
            headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
        )

        z = zipfile.ZipFile(io.BytesIO(response.content))
        output_folder = Path(name) / str(log["created_at"]).replace(" ", "_")
        z.extractall(output_folder)
        try:
            with open(output_folder / "ef-tests" / "11_run tests.txt", "r") as f:
                data = f.read()

            summary = next(
                re.finditer(
                    r"test result: (?P<result>\w+). (?P<passed>\d+) passed; (?P<failed>\d+) failed; (?P<ignored>\d+) ignored",
                    data,
                )
            )
            results += [{**log, **summary.groupdict()}]
        except (FileNotFoundError, StopIteration):
            continue

    ax = (
        pd.DataFrame(results)
        .drop(["logs_url", "result"], axis=1)
        .set_index("created_at")
        .astype(int)
        .plot.area()
    )
    ax.set_title("Ef-tests")
    plt.savefig(output_folder / "ef_tests.png")


def get_artifacts(
    name: Union[str, Path] = Path("resources"), base_branch_name: str = "main"
):
    # Pull latest main artifacts
    # https://api.github.com/repos/kkrt-labs/kakarot-ssj/releases/latest | jq -r '.assets[0].browser_download_url'
    response = requests.get(
        f"https://api.github.com/repos/krt-labs/kakarot/actions/artifacts?name={name}&per_page=50"
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

    for artifact in artifacts.to_dict("records"):
        response = requests.get(
            artifact["archive_download_url"],
            headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
        )

        z = zipfile.ZipFile(io.BytesIO(response.content))
        z.extractall(Path(name) / artifact["head_branch"])

    return artifacts


def fetch_deployments(path: str = "deployments"):
    response = requests.get(
        "https://api.github.com/repos/krt-labs/kakarot/actions/artifacts"
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
        raise ValueError("No deployment artifacts found for base branch main")

    github_token = os.getenv("GITHUB_TOKEN")
    if not github_token:
        raise ValueError("github token not found in environment variables")

    response = requests.get(
        artifacts.tolist()[0],
        headers={"Authorization": f"Bearer {github_token}"},
    )
    z = zipfile.ZipFile(io.BytesIO(response.content))
    z.extractall(path)
