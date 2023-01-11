import random
import re

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def precompiles(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_precompiles.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestPrecompiles:
    class TestPrecompilesRun:
        async def test_precompiles_should_throw_on_out_of_bounds(self, precompiles):
            # we choose an out of range precompile address to get the NotImplementedPrecompile error, and test if it is including the address in the error
            # note: in our implementation, `Precompiles.is_precompile` checks if an address is within a given range before dispatching, so usually an out of range address would never be passed to `Precompiles.run`
            last_precompile_address = 0x9
            address = last_precompile_address + 1
            with pytest.raises(Exception) as e:
                await precompiles.test__precompiles_should_throw_on_out_of_bounds(
                    address=address
                ).call()

            message = re.search(r"Error message: (.*)", e.value.message)[1]
            assert message == "Kakarot: NotImplementedPrecompile " + str(address)
