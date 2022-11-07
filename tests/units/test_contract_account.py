import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

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
        code_len = 10
        code = [random.randint(0, 255) for _ in range(code_len)]

        await contract_account.store_code(code).execute(caller_address=1)
        stored_code = await contract_account.code().call()
        assert stored_code.result.code == code
