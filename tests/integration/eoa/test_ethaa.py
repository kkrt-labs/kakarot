import os
import sys

import pytest
import web3
from eth_account._utils.legacy_transactions import (
    serializable_unsigned_transaction_from_dict,
)
from eth_keys import keys
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException

from tests.integration.helpers.helpers import int_to_uint256
from tests.utils.signer import MockEthSigner


@pytest.mark.asyncio
class TestExternallyOwnedAccount:
    class TestComputeStarknetAddress:
        async def test_should_return_same_address_as_contract(
            self, externally_owned_account, addresses
        ):
            (
                deployer,
                evm_eoas,
            ) = externally_owned_account

            for i in range(0, len(evm_eoas)):
                call_info = await deployer.compute_starknet_address(
                    evm_address=web3.Web3.toInt(hexstr=evm_eoas[i].address)
                ).call()
                assert (
                    call_info.result.contract_address
                    == addresses[i].starknet_contract.contract_address
                )

        async def test_should_return_the_eth_address_used_at_deploy(
            self, externally_owned_account, addresses
        ):
            (
                deployer,
                evm_eoas,
            ) = externally_owned_account
            for i in range(0, len(addresses)):
                call_info = (
                    await addresses[i].starknet_contract.get_eth_address().call()
                )
                assert call_info.result.eth_address == web3.Web3.toInt(
                    hexstr=evm_eoas[i].address
                )

    class TestEthSignature:
        async def test_should_validate_signature(
            self, externally_owned_account, default_tx, addresses
        ):
            (
                deployer,
                evm_eoas,
            ) = externally_owned_account
            for i in range(0, len(evm_eoas)):
                raw_tx = evm_eoas[i].sign_transaction(default_tx)
                tx_hash = serializable_unsigned_transaction_from_dict(default_tx).hash()
                call_info = (
                    await addresses[i]
                    .starknet_contract.is_valid_signature(
                        [*int_to_uint256(web3.Web3.toInt(tx_hash))],
                        [
                            raw_tx.v,
                            *int_to_uint256(raw_tx.r),
                            *int_to_uint256(raw_tx.s),
                        ],
                    )
                    .call()
                )
                assert call_info.result.is_valid == True

        async def test_should_fail_when_verifying_fake_signature(
            self, externally_owned_account, default_tx, addresses
        ):
            (
                deployer,
                evm_eoas,
            ) = externally_owned_account
            for i in range(0, len(evm_eoas)):
                raw_tx = evm_eoas[i].sign_transaction(default_tx)
                tx_hash = serializable_unsigned_transaction_from_dict(default_tx).hash()
                with pytest.raises(StarkException):
                    await addresses[i].starknet_contract.is_valid_signature(
                        [*int_to_uint256(web3.Web3.toInt(os.urandom(32)))],
                        [
                            raw_tx.v,
                            *int_to_uint256(raw_tx.r),
                            *int_to_uint256(raw_tx.s),
                        ],
                    ).call()

    class TestExecute:
        async def test_should_execute_tx(
            self, externally_owned_account, kakarot, default_tx, addresses
        ):
            (
                deployer,
                evm_eoas,
            ) = externally_owned_account
            for i in range(0, len(evm_eoas)):
                eth_account = MockEthSigner(private_key=addresses[i].private_key)

                raw_tx = evm_eoas[i].sign_transaction(default_tx)

                await eth_account.send_transaction(
                    addresses[i].starknet_contract,
                    kakarot.contract_address,
                    "execute_at_address",
                    raw_tx.rawTransaction,
                )

        async def test_should_fail_on_incorrect_signature(
            self, externally_owned_account, kakarot, default_tx, addresses
        ):
            (
                deployer,
                evm_eoas,
            ) = externally_owned_account
            for i in range(0, len(evm_eoas)):
                eth_account = MockEthSigner(private_key=addresses[i].private_key)
                fake_evm_eoa = web3.Account.from_key(os.urandom(32))
                raw_tx = fake_evm_eoa.sign_transaction(default_tx)
                with pytest.raises(StarkException):
                    await eth_account.send_transaction(
                        addresses[i].starknet_contract,
                        kakarot.contract_address,
                        "execute_at_address",
                        raw_tx.rawTransaction,
                    )
