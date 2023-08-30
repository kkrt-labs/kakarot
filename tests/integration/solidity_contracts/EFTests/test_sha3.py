import logging

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.helpers import hex_string_to_bytes_array

logger = logging.getLogger()


@pytest.mark.asyncio
@pytest.mark.EF_TEST
class TestSha3:
    @pytest.mark.skip(
        "TODO: need to fix when return_data is shorter than retSize in CallHelper.finalize_calling_context"
    )
    async def test_sha3_d0g0v0_Shanghai(
        self,
        owner,
        create_account_with_bytecode,
        kakarot: StarknetContract,
    ):
        called_contract = await create_account_with_bytecode("0x600060002060005500")
        caller_contract = await create_account_with_bytecode(
            "0x604060206010600f6000600435610100016001600003f100"
        )

        res = await kakarot.eth_send_transaction(
            to=int(caller_contract.evm_contract_address, 16),
            gas_limit=1_000_000,
            gas_price=0,
            value=0,
            data=hex_string_to_bytes_array(
                # In the original EF test, the called contract is supposed to be set in genesis
                # at address 0x000000000000000000000000000000000000010{i} while the payload of
                # the tx uses {i}, hence we sub 0x100 to the real deployed called_address
                f"0x693c6139{int(called_contract.evm_contract_address, 16) - 0x100:064x}"
            ),
        ).execute(caller_address=owner.starknet_address)
        sha3 = called_contract.storage(0).call()
        assert res == sha3
