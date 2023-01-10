import random

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.reporting import traceit

random.seed(0)


@pytest.mark.asyncio
class TestContractAccount:
    @pytest.mark.parametrize("bytecode_len", [0, 15, 16, 17, 30, 31, 32, 33])
    async def test_should_store_code(
        self, contract_account: StarknetContract, bytecode_len
    ):
        bytecode = [random.randint(0, 255) for _ in range(bytecode_len)]

        with traceit.context("contract_account"):
            await contract_account.write_bytecode(bytecode).execute(caller_address=1)
        stored_bytecode = (await contract_account.bytecode().call()).result.bytecode
        assert stored_bytecode == bytecode
