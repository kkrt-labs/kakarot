import asyncio
from typing import AsyncGenerator, List, cast

import pytest
import pytest_asyncio
from cairo_coverage import cairo_coverage
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.testing.starknet import Starknet


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.get_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def starknet() -> AsyncGenerator[Starknet, None]:
    starknet = await Starknet.empty()
    starknet.state.state.update_block_info(
        BlockInfo.create_for_testing(block_number=1, block_timestamp=1)
    )
    yield starknet
    files = cast(
        List[cairo_coverage.CoverageFile],
        cairo_coverage.report_runs(excluded_file={"site-packages", "cairo_files"}),
    )
    total_covered = []
    for file in files:
        if file.pct_covered < 80:
            print(f"WARNING: {file.name} only {file.pct_covered:.2f}% covered")
        total_covered.append(file.pct_covered)
    if (val := not sum(total_covered) / len(files)) >= 80:
        print(f"WARNING: Project is not covered enough {val:.2f})")


@pytest_asyncio.fixture(scope="session")
async def eth(starknet):
    return await starknet.deploy(
        source="./tests/utils/ERC20.cairo",
        constructor_calldata=[2] * 6,
    )
