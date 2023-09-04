import asyncio
import logging

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.helpers import (
    hex_string_to_bytes_array,
    private_key_from_hex,
)
from starkware.starknet.public.abi import get_storage_var_address
from starkware.starknet.testing.contract_utils import gather_deprecated_compiled_class
from tests.utils.uint256 import hex_string_to_uint256

logger = logging.getLogger()


@pytest.mark.asyncio
@pytest.mark.EF_TEST
@pytest.mark.SSTORE
class TestSSTORE:
    @pytest.mark.skip("TODO: deploy_contract_account should also increment nonce")
    async def test_InitCollision_d0g0v0_Shanghai(
        self,
        starknet,
        get_starknet_address,
        deploy_eoa,
        kakarot: StarknetContract,
    ):
        evm_contract_address = 0x6295EE1B4F6DD65047762F924ECD367C17EABF8F
        starknet_contract_address = get_starknet_address(evm_contract_address)

        # Set storage
        storage = {"0x01": "0x01"}
        storage_key = get_storage_var_address(
            "storage_", *hex_string_to_uint256("0x01")
        )
        keys = (storage_key, storage_key + 1)  # (low, high)
        values = hex_string_to_uint256(storage["0x01"])
        for key, value in zip(keys, values):
            await starknet.state.state.set_storage_at(
                starknet_contract_address, key, value
            )

        # Check initial storage
        storage_initial = await asyncio.gather(
            *(
                starknet.state.state.get_storage_at(starknet_contract_address, key)
                for key in keys
            )
        )
        assert storage_initial == list(hex_string_to_uint256(storage["0x01"]))

        # Check initial nonce
        nonce_key = get_storage_var_address("nonce")
        nonce_initial = await starknet.state.state.get_storage_at(
            starknet_contract_address, nonce_key
        )
        assert nonce_initial == 0

        # Deploy EOA
        # From https://github.com/ethereum/tests/blob/develop/src/GeneralStateTestsFiller/stSStoreTest/InitCollisionFiller.json#L155C28-L155C92
        private_key = private_key_from_hex(
            "45a915e4d060149eb4365960e6a7a45f334393093061116b197e3240065ff2d8"
        )
        caller_eoa = await deploy_eoa(private_key)

        # Send CREATE tx
        await kakarot.eth_send_transaction(
            to=0,
            gas_limit=200_000,
            gas_price=0,
            value=0,
            data=hex_string_to_bytes_array("0x6000600155600160015500"),
        ).execute(caller_address=caller_eoa.starknet_address)

        contract_account_class = gather_deprecated_compiled_class(
            source="./src/kakarot/accounts/contract/contract_account.cairo",
            cairo_path=["src"],
            disable_hint_validation=True,
        )

        contract_account = StarknetContract(
            starknet.state, contract_account_class.abi, starknet_contract_address, None
        )

        # Check storage, no change: 1 -> 0 -> 1
        storage_final = (
            await contract_account.storage(hex_string_to_uint256("0x01")).call()
        ).result.value
        assert storage_final == hex_string_to_uint256(storage["0x01"])

        # Check nonce, updated
        nonce_final = (await contract_account.get_nonce().call()).result.nonce
        assert nonce_final == 1
