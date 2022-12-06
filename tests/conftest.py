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
from starkware.starknet.business_logic.execution.execute_entry_point import (
    ExecuteEntryPoint,
)
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.utils import dump_coverage, dump_reports, timeit, traceit

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


@pytest.fixture(scope="session", autouse=True)
def trace_run():
    ExecuteEntryPoint._run = traceit.trace_run(ExecuteEntryPoint._run)
    return


@pytest_asyncio.fixture(scope="session")
async def starknet(worker_id) -> AsyncGenerator[Starknet, None]:
    starknet = await Starknet.empty()
    starknet.state.state.update_block_info(
        BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
    )

    starknet.deploy = traceit.trace_all(timeit(starknet.deploy))
    starknet.declare = timeit(starknet.declare)
    output_dir = Path("coverage")
    shutil.rmtree(output_dir, ignore_errors=True)

    yield starknet

    output_dir.mkdir(exist_ok=True, parents=True)
    files = cairo_coverage.report_runs(
        excluded_file={"site-packages", "cairo_files", "ERC20.cairo"}
    )
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
            # This is the last teardown of the testsuite, merge the files
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
        disable_hint_validation=True,
        constructor_calldata=[1],
    )


@pytest_asyncio.fixture(scope="session")
async def contract_account_class(starknet: Starknet):
    return await starknet.declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="package")
async def kakarot(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
) -> StarknetContract:
    return await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[
            1,
            eth.contract_address,
            contract_account_class.class_hash,
        ],
    )


@pytest_asyncio.fixture(scope="package", autouse=True)
async def set_account_registry(
    kakarot: StarknetContract, account_registry: StarknetContract
):
    await account_registry.transfer_ownership(kakarot.contract_address).execute(
        caller_address=1
    )
    await kakarot.set_account_registry(
        registry_address_=account_registry.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=kakarot.contract_address
    )
