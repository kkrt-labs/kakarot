import asyncio
import logging
import os
import shutil
from pathlib import Path
from typing import AsyncGenerator

import pandas as pd
import pytest
import pytest_asyncio
from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet

from tests.utils.utils import dump_reports, reports, timeit, traceit

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 500)
pd.set_option("display.width", 1000)
logging.getLogger("asyncio").setLevel(logging.ERROR)

logger = logging.getLogger()


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def starknet(worker_id) -> AsyncGenerator[Starknet, None]:
    starknet = await Starknet.empty()
    starknet.state.state.update_block_info(
        BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
    )

    starknet.deploy = traceit.trace_all(timeit(starknet.deploy))
    starknet.declare = timeit(starknet.declare)
    shutil.rmtree("coverage", ignore_errors=True)

    yield starknet

    files = cairo_coverage.report_runs(excluded_file={"site-packages", "cairo_files"})
    total_covered = []
    for file in files:
        if file.pct_covered < 80:
            logger.warn(f"{file.name} only {file.pct_covered:.2f}% covered")
        total_covered.append(file.pct_covered)
    if files and (val := not sum(total_covered) / len(files)) >= 80:
        logger.warn(f"Project is not covered enough {val:.2f})")

    if worker_id == "master":
        times, resources = reports()
        dump_reports(Path("coverage"))
    else:
        dump_reports(Path("coverage") / worker_id)
        if len(os.listdir("coverage")) == int(os.environ["PYTEST_XDIST_WORKER_COUNT"]):
            # This is the last teardown os the testsuite, merge the files
            resources = pd.concat(
                [pd.read_csv(f) for f in Path("coverage").glob("**/resources.csv")],
            ).sort_values(["n_steps"], ascending=False)
            resources.to_csv(Path("coverage") / "resources.csv", index=False)
            times = pd.concat(
                [pd.read_csv(f) for f in Path("coverage").glob("**/times.csv")],
                ignore_index=True,
            ).sort_values(["duration"], ascending=False)
            times.to_csv(Path("coverage") / "times.csv", index=False)


@pytest_asyncio.fixture(scope="session")
async def eth(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/utils/ERC20.cairo",
        constructor_calldata=[2] * 6,
        # Uint256(2, 2) tokens to 2
    )


@pytest_asyncio.fixture(scope="session")
async def account_registry(starknet: Starknet):
    return await starknet.deploy(
        source="./src/kakarot/accounts/registry/account_registry.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[1],
    )


@pytest_asyncio.fixture(scope="session")
async def contract_account_class(starknet: Starknet):
    return await starknet.declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )
