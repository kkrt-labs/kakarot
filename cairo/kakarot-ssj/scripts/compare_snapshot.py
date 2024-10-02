import json
import logging
import os
import re

# trunk-ignore(bandit/B404)
import subprocess
import tempfile
import zipfile
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_github_token_from_env(file_path=".env"):
    """Read the .env file and extract the GITHUB_TOKEN value."""
    try:
        with open(file_path, "r") as file:
            for line in file:
                if line.startswith("#"):
                    continue
                key, value = line.strip().split("=", 1)
                if key == "GITHUB_TOKEN":
                    return value if value != "" else None
    except FileNotFoundError:
        return None
    except ValueError:
        logger.error(
            f"Error: Invalid format in {file_path}. Expected 'KEY=VALUE' format."
        )
    return None


def get_previous_snapshot():
    REPO = "kkrt-labs/kakarot-ssj"  # Replace with your GitHub username and repo name
    GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", get_github_token_from_env())
    if GITHUB_TOKEN is None:
        raise ValueError(
            "GITHUB_TOKEN doesn't exist in current shell nor is defined .env"
        )

    # Fetch the list of workflow runs
    cmd = f"curl -s -H 'Authorization: token {GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/{REPO}/actions/runs?branch=main&per_page=100'"
    # trunk-ignore(bandit/B602)
    result = subprocess.check_output(cmd, shell=True)
    runs = json.loads(result)

    # Find the latest successful run
    latest_successful_run = next(
        (
            run
            for run in runs["workflow_runs"]
            if run["conclusion"] == "success"
            and run["name"] == "Generate and Upload Gas Snapshot"
        ),
        None,
    )

    if latest_successful_run is None:
        return

    # Fetch the artifacts for that run
    run_id = latest_successful_run["id"]
    cmd = f"curl -s -H 'Authorization: token {GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts'"
    # trunk-ignore(bandit/B602)
    result = subprocess.check_output(cmd, shell=True)
    artifacts = json.loads(result)

    # Find the gas_snapshot.json artifact
    snapshot_artifact = next(
        (
            artifact
            for artifact in artifacts["artifacts"]
            if artifact["name"] == "gas-snapshot"
        ),
        None,
    )

    if snapshot_artifact is None:
        return

    # Download the gas_snapshots.json archive
    temp_dir = Path(tempfile.mkdtemp())

    archive_name = temp_dir / "gas_snapshot.zip"
    cmd = f"curl -s -L -o {archive_name} -H 'Authorization: token {GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v3+json' '{snapshot_artifact['archive_download_url']}'"
    # trunk-ignore(bandit/B602)
    subprocess.check_call(cmd, shell=True)
    with zipfile.ZipFile(archive_name, "r") as archive:
        archive.extractall(temp_dir)

    return json.loads(archive_name.with_suffix(".json").read_text())


def get_current_gas_snapshot():
    """Execute command and return current gas snapshots."""
    # trunk-ignore(bandit/B602)
    # trunk-ignore(bandit/B607)
    output = subprocess.check_output("scarb test", shell=True).decode("utf-8")
    pattern = r"test ([\w\:]+).*gas usage est\.\: (\d+)"
    matches = re.findall(pattern, output)
    matches.sort()
    return {match[0]: int(match[1]) for match in matches}


def compare_snapshots(current, previous):
    """Compare current and previous snapshots and return differences."""
    worsened = []
    improvements = []
    common_keys = list(set(current.keys()) & set(previous.keys()))
    common_keys.sort()
    max_key_len = max(len(key) for key in common_keys)
    for key in common_keys:
        prev = previous[key]
        cur = current[key]
        log = (
            f"|{key:<{max_key_len + 5}} | {prev:>10} | {cur:>10} | {cur / prev:>6.2%}|"
        )
        if prev < cur:
            worsened.append(log)
        elif prev > cur:
            improvements.append(log)

    return improvements, worsened


def total_gas_used(current, previous):
    """Return the total gas used in the current and previous snapshot, not taking into account added tests."""
    common_keys = set(current.keys()) & set(previous.keys())

    cur_gas = sum(current[key] for key in common_keys)
    prev_gas = sum(previous[key] for key in common_keys)

    return cur_gas, prev_gas


def main():
    previous_snapshot = get_previous_snapshot()
    if previous_snapshot is None:
        logger.error("Error: Failed to load previous snapshot.")
        return

    current_snapshots = get_current_gas_snapshot()
    improvements, worsened = compare_snapshots(current_snapshots, previous_snapshot)
    cur_gas, prev_gas = total_gas_used(current_snapshots, previous_snapshot)
    header = [
        "| Test | Prev | Cur | Ratio |",
        "| ---- | ---- | --- | ----- |",
    ]
    if improvements:
        logger.info("\n".join(["****BETTER****"] + header + improvements))
    if worsened:
        logger.info("\n".join(["****WORST****"] + header + worsened))

    logger.info(
        f"\nTotal gas change: {prev_gas} -> {cur_gas} ({cur_gas / prev_gas:.2%})"
    )
    if worsened:
        logger.error("Gas usage increased")
    else:
        logger.info("Gas change ✅")


if __name__ == "__main__":
    main()
