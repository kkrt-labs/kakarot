import logging

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.helpers import (
    hex_string_to_bytes_array,
    hex_string_to_uint256,
    private_key_from_hex,
)

logger = logging.getLogger()


@pytest.mark.asyncio
@pytest.mark.EF_TEST
@pytest.mark.SSTORE
class TestSSTORE:
    @pytest.mark.skip("TODO: investigate why nonce is still not updated")
    async def test_InitCollision_d0g0v0_Shanghai(
        self,
        deploy_eoa,
        create_account_with_bytecode_and_storage,
        kakarot: StarknetContract,
    ):
        # Deploy EOA
        # From https://github.com/ethereum/tests/blob/develop/src/GeneralStateTestsFiller/stSStoreTest/InitCollisionFiller.json#L155C28-L155C92
        private_key = private_key_from_hex(
            "45a915e4d060149eb4365960e6a7a45f334393093061116b197e3240065ff2d8"
        )
        caller_eoa = await deploy_eoa(private_key)

        # Pre-deploy contract account
        storage = {"0x01": "0x01"}
        contract_account = await create_account_with_bytecode_and_storage(
            bytecode="", storage=storage, caller_eoa=caller_eoa
        )
        # https://github.com/ethereum/tests/blob/develop/BlockchainTests/GeneralStateTests/stSStoreTest/InitCollision.json#L685
        assert (
            contract_account.evm_contract_address
            == "0x6295eE1B4F6dD65047762F924Ecd367c17eaBf8f"
        )
        storage_initial = (
            await contract_account.storage(hex_string_to_uint256("0x01")).call()
        ).result.value
        assert storage_initial == hex_string_to_uint256("0x01")
        nonce_initial = (await contract_account.get_nonce().call()).result.nonce
        assert nonce_initial == 0

        # Send tx
        _ = await kakarot.eth_send_transaction(
            origin=int(caller_eoa.address, 16),
            to=0,
            gas_limit=200_000,
            gas_price=0,
            value=0,
            data=hex_string_to_bytes_array("0x6000600155600160015500"),
        ).execute(caller_address=caller_eoa.starknet_address)

        # Check storage, no change: 1 -> 0 -> 1
        storage_final = (
            await contract_account.storage(hex_string_to_uint256("0x01")).call()
        ).result.value
        assert storage_final == hex_string_to_uint256("0x01")

        # Check nonce, updated
        nonce_final = (await contract_account.get_nonce().call()).result.nonce
        assert nonce_final == 1
