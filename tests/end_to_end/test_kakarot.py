import logging

import pytest
import pytest_asyncio
from starknet_py.contract import Contract
from starknet_py.net.full_node_client import FullNodeClient

from kakarot_scripts.utils.kakarot import get_eoa, get_solidity_artifacts
from kakarot_scripts.utils.starknet import wait_for_transaction
from tests.end_to_end.bytecodes import test_cases
from tests.utils.constants import TRANSACTION_GAS_LIMIT
from tests.utils.helpers import (
    extract_memory_from_execute,
    generate_random_evm_address,
    hex_string_to_bytes_array,
)
from tests.utils.syscall_handler import SyscallHandler

params_execute = [pytest.param(case.pop("params"), **case) for case in test_cases]


logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


@pytest.fixture(scope="session")
def evm(get_contract):
    """
    Return a cached EVM contract.
    """

    return get_contract("EVM")


@pytest_asyncio.fixture(scope="session")
async def other():
    """
    Just another Starknet contract.
    """
    from kakarot_scripts.utils.starknet import (
        deploy_starknet_account,
        get_starknet_account,
    )

    account_info = await deploy_starknet_account()
    return await get_starknet_account(account_info["address"])


@pytest.fixture(scope="session")
def class_hashes():
    """
    All declared class hashes.
    """
    from kakarot_scripts.utils.starknet import get_declarations

    return get_declarations()


@pytest_asyncio.fixture(scope="session")
async def origin(evm: Contract, max_fee):
    """
    Deploys the origin's Starknet contract to the correct address.
    """
    from tests.utils.helpers import generate_random_private_key

    private_key = generate_random_private_key()
    evm_address = int(private_key.public_key.to_checksum_address(), 16)
    is_deployed = (await evm.functions["is_deployed"].call(evm_address)).deployed
    if is_deployed:
        return evm_address
    tx = await evm.functions["deploy_account"].invoke_v1(evm_address, max_fee=max_fee)
    await wait_for_transaction(tx.hash)
    return evm_address


@pytest.mark.asyncio(scope="session")
class TestKakarot:
    class TestEVM:
        @pytest.mark.parametrize("params", params_execute)
        async def test_execute(
            self,
            starknet: FullNodeClient,
            eth: Contract,
            params: dict,
            request,
            evm: Contract,
            max_fee,
            origin,
        ):
            result = await evm.functions["evm_call"].call(
                origin=origin,
                value=int(params["value"]),
                bytecode=hex_string_to_bytes_array(params["code"]),
                calldata=hex_string_to_bytes_array(params["calldata"]),
                access_list=[],
            )
            assert result.success == params["success"]
            assert result.stack_values[: result.stack_size] == (
                [
                    int(x)
                    for x in params["stack"]
                    .format(
                        account_address=origin,
                        timestamp=result.block_timestamp,
                        block_number=result.block_number,
                    )
                    .split(",")
                ]
                if params["stack"]
                else []
            )
            assert bytes(extract_memory_from_execute(result)).hex() == params["memory"]
            assert bytes(result.return_data).hex() == params["return_data"]

            events = params.get("events")
            if events:
                # Events only show up in a transaction, thus we run the same call, but in a tx
                tx = await evm.functions["evm_execute"].invoke_v1(
                    origin=origin,
                    value=int(params["value"]),
                    bytecode=hex_string_to_bytes_array(params["code"]),
                    calldata=hex_string_to_bytes_array(params["calldata"]),
                    max_fee=max_fee,
                    access_list=[],
                )
                status = await wait_for_transaction(
                    tx.hash,
                )
                assert status == "✅"
                receipt = await starknet.get_transaction_receipt(tx.hash)
                assert [
                    [
                        # we remove the key that is used to convey the emitting kakarot evm contract
                        event.keys[1:],
                        event.data,
                    ]
                    for event in receipt.events
                    if event.from_address != eth.address
                ] == events

    class TestComputeStarknetAddress:
        async def test_should_return_same_as_deployed_address(
            self, compute_starknet_address, addresses
        ):
            eoa = addresses[0]
            starknet_address = await compute_starknet_address(eoa.address)
            assert eoa.starknet_contract.address == starknet_address

    class TestDeployExternallyOwnedAccount:
        async def test_should_deploy_starknet_contract_at_corresponding_address(
            self,
            deploy_externally_owned_account,
            compute_starknet_address,
            get_contract,
            random_seed,
        ):
            evm_address = generate_random_evm_address(random_seed)
            starknet_address = await compute_starknet_address(evm_address)

            await deploy_externally_owned_account(evm_address)
            eoa = get_contract("account_contract", address=starknet_address)
            actual_evm_address = (await eoa.functions["get_evm_address"].call()).address
            assert actual_evm_address == int(evm_address, 16)

    class TestRegisterAccount:
        async def test_should_fail_when_sender_is_not_account(
            self,
            starknet: FullNodeClient,
            register_account,
            compute_starknet_address,
            random_seed,
        ):
            evm_address = generate_random_evm_address(random_seed)
            await compute_starknet_address(evm_address)

            tx = await register_account(evm_address)
            receipt = await starknet.get_transaction_receipt(tx.hash)
            assert receipt.execution_status.name == "REVERTED"
            assert "Kakarot: Caller should be" in receipt.revert_reason

        async def test_should_fail_when_account_is_already_registered(
            self,
            starknet: FullNodeClient,
            deploy_externally_owned_account,
            register_account,
            random_seed,
        ):
            evm_address = generate_random_evm_address(random_seed)
            await deploy_externally_owned_account(evm_address)
            tx = await register_account(evm_address)
            receipt = await starknet.get_transaction_receipt(tx.hash)
            assert receipt.execution_status.name == "REVERTED"
            assert "Kakarot: account already registered" in receipt.revert_reason

    class TestSetAccountStorage:
        class TestWriteAccountBytecode:
            async def test_should_set_account_bytecode(
                self,
                deploy_externally_owned_account,
                invoke,
                compute_starknet_address,
                get_contract,
                random_seed,
            ):
                counter_artifacts = get_solidity_artifacts("PlainOpcodes", "Counter")
                evm_address = generate_random_evm_address(random_seed)
                await deploy_externally_owned_account(evm_address)

                bytecode = list(bytes.fromhex(counter_artifacts["bytecode"][2:]))
                await invoke(
                    "kakarot",
                    "write_account_bytecode",
                    int(evm_address, 16),
                    bytecode,
                )

                eoa = get_contract(
                    "account_contract",
                    address=await compute_starknet_address(evm_address),
                )
                stored_code = (await eoa.functions["bytecode"].call()).bytecode
                assert stored_code == bytecode

            async def test_should_fail_not_owner(
                self,
                starknet: FullNodeClient,
                deploy_externally_owned_account,
                invoke,
                random_seed,
                other,
            ):
                counter_artifacts = get_solidity_artifacts("PlainOpcodes", "Counter")
                evm_address = generate_random_evm_address(random_seed)
                await deploy_externally_owned_account(evm_address)

                bytecode = list(bytes.fromhex(counter_artifacts["bytecode"][2:]))
                tx_hash = await invoke(
                    "kakarot",
                    "write_account_bytecode",
                    int(evm_address, 16),
                    bytecode,
                    account=other,
                )
                receipt = await starknet.get_transaction_receipt(tx_hash)
                assert receipt.execution_status.name == "REVERTED"
                assert "Ownable: caller is not the owner" in receipt.revert_reason

        class TestWriteAccountNonce:

            async def test_should_set_account_nonce(
                self,
                deploy_externally_owned_account,
                invoke,
                compute_starknet_address,
                get_contract,
                random_seed,
            ):
                evm_address = generate_random_evm_address(random_seed)
                await deploy_externally_owned_account(evm_address)
                eoa = get_contract(
                    "account_contract",
                    address=await compute_starknet_address(evm_address),
                )
                prev_nonce = (await eoa.functions["get_nonce"].call()).nonce

                await invoke(
                    "kakarot",
                    "write_account_nonce",
                    int(evm_address, 16),
                    prev_nonce + 1,
                )

                stored_nonce = (await eoa.functions["get_nonce"].call()).nonce
                assert stored_nonce == prev_nonce + 1

            async def test_should_fail_not_owner(
                self,
                starknet: FullNodeClient,
                deploy_externally_owned_account,
                invoke,
                compute_starknet_address,
                get_contract,
                random_seed,
                other,
            ):
                evm_address = generate_random_evm_address(random_seed)
                await deploy_externally_owned_account(evm_address)
                eoa = get_contract(
                    "account_contract",
                    address=await compute_starknet_address(evm_address),
                )
                prev_nonce = (await eoa.functions["get_nonce"].call()).nonce

                tx_hash = await invoke(
                    "kakarot",
                    "write_account_nonce",
                    int(evm_address, 16),
                    prev_nonce + 1,
                    account=other,
                )
                receipt = await starknet.get_transaction_receipt(tx_hash)
                assert receipt.execution_status.name == "REVERTED"
                assert "Ownable: caller is not the owner" in receipt.revert_reason

    class TestUpgradeAccount:
        async def test_should_upgrade_account_class(
            self,
            starknet: FullNodeClient,
            invoke,
            new_eoa,
            class_hashes,
        ):
            account = await new_eoa()

            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                class_hashes["uninitialized_account_fixture"],
            )

            await invoke("kakarot", "upgrade_account", int(account.address, 16))
            assert (
                await starknet.get_class_hash_at(account.starknet_contract.address)
                == class_hashes["uninitialized_account_fixture"]
            ), "Class not upgraded"

        async def test_should_fail_not_owner(
            self, starknet: FullNodeClient, invoke, new_eoa, class_hashes, other
        ):
            account = await new_eoa()

            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                class_hashes["uninitialized_account_fixture"],
            )

            tx_hash = await invoke(
                "kakarot", "upgrade_account", int(account.address, 16), account=other
            )
            receipt = await starknet.get_transaction_receipt(tx_hash)
            assert receipt.execution_status.name == "REVERTED"
            assert "Ownable: caller is not the owner" in receipt.revert_reason

    class TestEthCallNativeCoinTransfer:
        async def test_eth_call_should_succeed(
            self,
            fund_starknet_address,
            deploy_externally_owned_account,
            is_account_deployed,
            compute_starknet_address,
            kakarot,
            random_seed,
            new_eoa,
        ):
            eoa = await new_eoa()
            result = await kakarot.functions["eth_call"].call(
                nonce=0,
                origin=int(eoa.address, 16),
                to={"is_some": 1, "value": 0xDEAD},
                gas_limit=TRANSACTION_GAS_LIMIT,
                gas_price=1_000,
                value=1_000,
                data=bytes(),
                access_list=[],
            )

            assert result.success == 1
            assert result.return_data == []
            assert result.gas_used == 21_000

    class TestUpgrade:
        async def test_should_raise_when_caller_is_not_owner(
            self, starknet, kakarot, invoke, other, class_hashes
        ):
            tx_hash = await invoke(
                "kakarot", "upgrade", class_hashes["EVM"], account=other
            )
            receipt = await starknet.get_transaction_receipt(tx_hash)
            assert receipt.execution_status.name == "REVERTED"
            assert "Ownable: caller is not the owner" in receipt.revert_reason

        async def test_should_raise_when_class_hash_is_not_declared(
            self, starknet, kakarot, invoke
        ):
            tx_hash = await invoke("kakarot", "upgrade", 0xDEAD)
            receipt = await starknet.get_transaction_receipt(tx_hash)
            assert receipt.execution_status.name == "REVERTED"
            assert "is not declared" in receipt.revert_reason

        async def test_should_upgrade_class_hash(
            self, starknet, kakarot, invoke, class_hashes
        ):
            prev_class_hash = await starknet.get_class_hash_at(kakarot.address)
            await invoke("kakarot", "upgrade", class_hashes["replace_class"])
            new_class_hash = await starknet.get_class_hash_at(kakarot.address)
            assert prev_class_hash != new_class_hash
            assert new_class_hash == class_hashes["replace_class"]
            await invoke("kakarot", "upgrade", prev_class_hash)

    class TestTransferOwnership:
        @SyscallHandler.patch("Ownable_owner", 0xDEAD)
        async def test_should_raise_when_caller_is_not_owner(
            self, kakarot, invoke, other
        ):
            prev_owner = await kakarot.functions["get_owner"].call()
            try:
                await invoke("kakarot", "transfer_ownership", account=other)
            except Exception as e:
                print(e)
            new_owner = await kakarot.functions["get_owner"].call()
            assert prev_owner == new_owner

        @SyscallHandler.patch("Ownable_owner", SyscallHandler.caller_address)
        async def test_should_transfer_ownership(self, kakarot, invoke, other):
            prev_owner = (await kakarot.functions["get_owner"].call()).owner
            await invoke("kakarot", "transfer_ownership", other.address)
            new_owner = (await kakarot.functions["get_owner"].call()).owner

            assert prev_owner != new_owner
            assert new_owner == other.address

            await invoke("kakarot", "transfer_ownership", prev_owner, account=other)

    class TestBlockTransactionViewEntrypoint:

        @pytest.mark.parametrize("view_entrypoint", ["eth_call", "eth_estimate_gas"])
        async def test_should_raise_when_tx_view_entrypoint(
            self, starknet, kakarot, invoke, view_entrypoint
        ):

            evm_account = await get_eoa()
            calldata = bytes.fromhex("6001")
            tx_hash = await invoke(
                "kakarot",
                view_entrypoint,
                0,  # nonce
                int(evm_account.signer.public_key.to_address(), 16),  # origin
                {"is_some": False, "value": 0},  # to
                10,  # gas_limit
                10,  # gas_price
                10,  # value
                list(calldata),  # data
                {},  # access_list
            )
            receipt = await starknet.get_transaction_receipt(tx_hash)
            assert receipt.execution_status.name == "REVERTED"
            assert "Only view call" in receipt.revert_reason
