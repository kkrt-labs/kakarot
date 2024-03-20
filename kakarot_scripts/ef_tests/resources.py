# Imports
import io
import json
import logging
import os
import re
import zipfile
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import requests
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_resources(resources_dir: Path = Path("resources")):
    # Pull latest main artifacts
    response = requests.get(
        "https://api.github.com/repos/kkrt-labs/kakarot/actions/workflows/ci.yml/runs?branch=main"
    )
    runs = (
        pd.DataFrame(response.json()["workflow_runs"])
        .reindex(columns=["logs_url", "display_title", "updated_at"])
        .assign(pr=lambda df: df.display_title.str.extract(r".*#(\d+)"))
        .dropna()
        .astype({"updated_at": "datetime64[s]"})
        .sort_values("updated_at", ascending=True)
    )

    resources = []
    for run in runs.to_dict("records"):
        if not (resources_dir / Path(run["logs_url"]).parent.name).exists():
            response = requests.get(
                run["logs_url"],
                headers={"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"},
            )

            z = zipfile.ZipFile(io.BytesIO(response.content))
            z.extractall(resources_dir / Path(run["logs_url"]).parent.name)

        log = (
            resources_dir
            / Path(run["logs_url"]).parent.name
            / "ef-tests"
            / "7_run tests.txt"
        )
        if not log.exists():
            continue

        matches = re.findall(
            r"ef_testing::models::result: (.*) passed: .?ResourcesMapping\((.*)\)",
            re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", log.read_text()),
        )
        resources.append(
            pd.DataFrame(
                [
                    {**json.loads(resources), "test": test_name}
                    for test_name, resources in matches
                ]
            ).assign(**run)
        )
    resources_df = pd.concat(resources, ignore_index=True)
    (
        resources_df.loc[lambda df: df.n_steps < 5 * 10**5]
        .pivot_table(index="test", columns=["display_title"], values="n_steps")
        .sort_index(
            axis=1,
            key=lambda index: [int(re.findall(r".*#(\d+)", x)[0]) for x in index],
        )
        .plot.box(logy=True, rot=90, ylabel="Steps")
    )
    plt.tight_layout()
    plt.savefig(resources_dir / "average_steps.png")


if __name__ == "__main__":
    get_resources()
