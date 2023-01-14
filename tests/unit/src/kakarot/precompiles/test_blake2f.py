import re

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def blake2f(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_blake2f.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.BLAKE2F
class TestBlake2f:
    async def test_should_fail_when_input_len_is_not_213(self, blake2f):
        with pytest.raises(Exception) as e:
            await blake2f.test_should_fail_when_input_is_not_213().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1] 
        assert (
            message
            == "Kakarot: blake2f failed with incorrect input_len: 212 instead of 213"
        )
    async def test_should_fail_when_flag_is_not_0_or_1(self, blake2f):
        with pytest.raises(Exception) as e:
            await blake2f.test_should_fail_when_flag_is_not_0_or_1().call()
        message = re.search(r"Error message: (.*)", e.value.message)[1] 
        assert (
            message
            == "Kakarot: blake2f failed with incorrect flag: 2 instead of 0 or 1"
        )
    async def test_should_return_blake2f_compression(self, blake2f):
        await blake2f.test_should_return_blake2f_compression().call()