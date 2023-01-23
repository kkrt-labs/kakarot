import logging
import os
import shutil
from pathlib import Path
from typing import AsyncGenerator

import pandas as pd
import pytest
import pytest_asyncio
from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.execution.execute_entry_point import (
    ExecuteEntryPoint,
)
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.definitions.general_config import StarknetGeneralConfig

from tests.utils.reporting import dump_coverage, dump_reports, timeit, traceit

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 500)
pd.set_option("display.width", 1000)

logging.getLogger("asyncio").setLevel(logging.ERROR)
logger = logging.getLogger()


@pytest_asyncio.fixture(scope="session")
async def starknet(worker_id, request, blockhashes) -> AsyncGenerator[Starknet, None]:
    config = StarknetGeneralConfig(invoke_tx_max_n_steps=2**24, validate_max_n_steps=2**24)
    starknet = await Starknet.empty(config)
    current_block_number = blockhashes["current_block"]["block_number"]
    current_block_timestamp = blockhashes["current_block"]["timestamp"]
    starknet.state.state.update_block_info(
        BlockInfo.create_for_testing(
            block_number=current_block_number, block_timestamp=current_block_timestamp
        )
    )

    starknet.deploy = traceit.trace_all(timeit(starknet.deploy))
    starknet.declare = timeit(starknet.declare)
    if request.config.getoption("trace_run"):
        logger.info("trace-run option enabled")
        ExecuteEntryPoint._run = traceit.trace_run(ExecuteEntryPoint._run)
    else:
        logger.info("trace-run option disabled")
    output_dir = Path("coverage")
    shutil.rmtree(output_dir, ignore_errors=True)

    yield starknet

    output_dir.mkdir(exist_ok=True, parents=True)
    files = cairo_coverage.report_runs(excluded_file={"site-packages", "tests"})
    total_covered = []
    for file in files:
        if file.pct_covered < 80:
            logger.warning(f"{file.name} only {file.pct_covered:.2f}% covered")
        total_covered.append(file.pct_covered)
    if files and (val := not sum(total_covered) / len(files)) >= 80:
        logger.warning(f"Project is not covered enough {val:.2f})")

    if worker_id == "master":
        dump_reports(output_dir)
        dump_coverage(output_dir, files)
    else:
        dump_reports(output_dir / worker_id)
        dump_coverage(output_dir / worker_id, files)
        if len(os.listdir(output_dir)) == int(os.environ["PYTEST_XDIST_WORKER_COUNT"]):
            # This is the last teardown of the test suite, merge the files
            resources = pd.concat(
                [pd.read_csv(f) for f in output_dir.glob("**/resources.csv")],
            )
            if not resources.empty:
                resources.sort_values(["n_steps"], ascending=False).to_csv(
                    output_dir / "resources.csv", index=False
                )
            times = pd.concat(
                [pd.read_csv(f) for f in output_dir.glob("**/times.csv")],
                ignore_index=True,
            )
            if not times.empty:
                times.sort_values(["duration"], ascending=False).to_csv(
                    output_dir / "times.csv", index=False
                )


@pytest.fixture()
def starknet_snapshot(starknet):
    """
    Use this fixture to snapshot the starknet state before each test and reset it at teardown
    """
    initial_state = starknet.state.copy()

    yield

    initial_cache_state = initial_state.state._copy()
    starknet.state.state = initial_cache_state
