import re

import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def stack(starknet):
    return await starknet.deploy(
        source="./tests/unit/utils/test_utils.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
    )


@pytest.mark.asyncio
class TestStack:
    async def test__bytes_i_to_uint256(self, stack):
        await stack.test__bytes_i_to_uint256().call()
