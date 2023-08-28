import logging

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.helpers import hex_string_to_bytes_array
from tests.utils.uint256 import uint256_to_int

logger = logging.getLogger()


@pytest.mark.asyncio
@pytest.mark.EF_TEST
class TestSha3:
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

        # this is derived from https://github.com/ethereum/tests/blob/develop/src/GeneralStateTestsFiller/VMTests/vmTests/sha3Filler.yml#L313
        expected_sha3 = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470

        res = await kakarot.eth_send_transaction(
            origin=int(owner.address, 16),
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
        sha3 = await called_contract.storage((0, 0)).call()
        actual_sha3 = uint256_to_int(sha3.result.value.low, sha3.result.value.high)

        assert expected_sha3 == actual_sha3
