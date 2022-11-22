import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.utils import traceit

random.seed(0)


@pytest_asyncio.fixture(scope="session")
async def contract_account(starknet: Starknet):
    return await starknet.deploy(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[1, 0],
    )


@pytest.mark.asyncio
class TestContractAccount:
    async def test_should_store_code(self, contract_account: StarknetContract):
        bytecode_len = 10
        bytecode = [random.randint(0, 255) for _ in range(bytecode_len)]

        with traceit.context("contract_account"):
            await contract_account.write_bytecode(bytecode, 10).execute(
                caller_address=1
            )
        stored_bytecode = await contract_account.bytecode().call()
        assert stored_bytecode.result.bytecode == bytecode
