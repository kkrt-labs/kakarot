# %% Imports
import logging
from pathlib import Path

import pandas as pd

from kakarot_scripts.artifacts import get_artifacts

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 10)
pd.set_option("display.width", 1000)
pd.set_option("max_colwidth", 400)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# %% Main
def main():
    # %% Script constants
    artifact_name = Path("resources")
    base_branch_name = "main"
    current_name = "local"

    artifacts = get_artifacts(artifact_name, base_branch_name)

    # %% Build aggregated stat for checking resources evolution
    resources = []
    for artifact in artifacts.to_dict("records"):
        file_path = next(
            (artifact_name / artifact["head_branch"]).glob("resources*.csv")
        )
        resources.append(
            pd.read_csv(file_path).assign(head_branch=artifact["head_branch"])
        )

    local_artifact = list(artifact_name.glob("resources*.csv"))
    if local_artifact:
        resources.append(
            pd.read_csv(local_artifact[0]).assign(head_branch=current_name)
        )
    else:
        logger.info("No local resources found to compare against")

    all_resources = (
        # There shouldn't be any duplicated, but rn we only have the test name, so
        # to avoid any confusion we just drop them
        pd.concat(resources)
        .drop_duplicates(["head_branch", "test"], keep=False)
        .set_index(["head_branch", "test"])
    )
    average_summary = all_resources.groupby(level="head_branch").agg("mean").round(2)
    logger.info(f"### Resources summary\n\n{average_summary.to_markdown()}")


# %% Run
if __name__ == "__main__":
    main()
