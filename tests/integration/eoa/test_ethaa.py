import os

import pytest
import web3
from eth_account._utils.legacy_transactions import (
    serializable_unsigned_transaction_from_dict,
)
from starkware.starkware_utils.error_handling import StarkException

from tests.utils.signer import MockEthSigner
from tests.utils.uint256 import int_to_uint256


@pytest.mark.asyncio
class TestExternallyOwnedAccount:
    class TestComputeStarknetAddress:
        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_return_same_address_as_contract(
            self, deployer, addresses, address_idx
        ):
            address = addresses[address_idx]
            call_info = await deployer.compute_starknet_address(
                evm_address=int(address.address, 16)
            ).call()
            assert (
                call_info.result.contract_address
                == address.starknet_contract.contract_address
            )

        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_return_the_eth_address_used_at_deploy(
            self, addresses, address_idx
        ):
            address = addresses[address_idx]
            call_info = await address.starknet_contract.get_eth_address().call()
            assert call_info.result.eth_address == int(address.address, 16)

    class TestEthSignature:
        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_validate_signature(
            self, default_tx, addresses, address_idx
        ):
            address = addresses[address_idx]
            tmp_account = web3.Account.from_key(address.private_key)
            raw_tx = tmp_account.sign_transaction(default_tx)
            tx_hash = serializable_unsigned_transaction_from_dict(default_tx).hash()
            call_info = await address.starknet_contract.is_valid_signature(
                [*int_to_uint256(web3.Web3.toInt(tx_hash))],
                [
                    raw_tx.v,
                    *int_to_uint256(raw_tx.r),
                    *int_to_uint256(raw_tx.s),
                ],
            ).call()
            assert call_info.result.is_valid == True

        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_fail_when_verifying_fake_signature(
            self, default_tx, addresses, address_idx
        ):
            address = addresses[address_idx]
            tmp_account = web3.Account.from_key(address.private_key)
            raw_tx = tmp_account.sign_transaction(default_tx)
            with pytest.raises(StarkException):
                await address.starknet_contract.is_valid_signature(
                    [*int_to_uint256(web3.Web3.toInt(os.urandom(32)))],
                    [
                        raw_tx.v,
                        *int_to_uint256(raw_tx.r),
                        *int_to_uint256(raw_tx.s),
                    ],
                ).call()

    class TestExecute:
        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_execute_tx(
            self, kakarot, default_tx, addresses, address_idx
        ):
            address = addresses[address_idx]
            eth_account = MockEthSigner(private_key=address.private_key)
            tmp_account = web3.Account().from_key(address.private_key)
            raw_tx = tmp_account.sign_transaction(default_tx)

            await eth_account.send_transaction(
                account=address.starknet_contract,
                to=kakarot.contract_address,
                selector_name="execute_at_address",
                calldata=raw_tx.rawTransaction,
                # max_fee=default_tx["gas"]*(default_tx["maxFeePerGas"] +
                #                            default_tx["maxPriorityFeePerGas"])
            )

        @pytest.mark.parametrize("address_idx", range(1))
        async def test_should_execute_legacy_tx(
            self, kakarot, legacy_tx, deploy_solidity_contract, addresses, address_idx, owner
        ):
            address = addresses[address_idx]
            eth_account = MockEthSigner(private_key=address.private_key)
            tmp_account = web3.Account().from_key(address.private_key)
            # We require a contract to target
            counter = await deploy_solidity_contract(
                "PlainOpcodes", "Counter", caller_address=owner.starknet_address
            )
            legacy_tx["to"] = counter.evm_contract_address
            legacy_tx["data"] = bytes.fromhex(counter.encodeABI("inc", [], {})[2:])
            raw_tx = tmp_account.sign_transaction(legacy_tx)

            await eth_account.send_transaction(
                account=address.starknet_contract,
                to=kakarot.contract_address,
                selector_name="execute_at_address",
                calldata=list(web3.Web3.toBytes(raw_tx.rawTransaction)),
                # max_fee=legacy_tx["gas"]*legacy_tx["gasPrice"]
            )

        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_fail_on_incorrect_signature(
            self, kakarot, default_tx, addresses, address_idx
        ):
            address = addresses[address_idx]
            eth_account = MockEthSigner(private_key=address.private_key)
            fake_evm_eoa = web3.Account.from_key(os.urandom(32))
            raw_tx = fake_evm_eoa.sign_transaction(default_tx)
            with pytest.raises(StarkException):
                await eth_account.send_transaction(
                    address.starknet_contract,
                    kakarot.contract_address,
                    "execute_at_address",
                    raw_tx.rawTransaction,
                )

        # test should fail on incorrect gas
