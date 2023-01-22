import string

import pytest
import pytest_asyncio
from eth_utils import decode_hex, to_bytes, to_checksum_address
from starkware.python.utils import from_bytes
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.integration.helpers.helpers import get_create2_address
from tests.utils.errors import kakarot_error
from tests.utils.uint256 import int_to_uint256


@pytest_asyncio.fixture(scope="module")
async def system_operations(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_system_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="module", autouse=True)
async def set_account_registry(
    system_operations: StarknetContract, account_registry: StarknetContract
):
    await account_registry.transfer_ownership(
        system_operations.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=system_operations.contract_address
    )


@pytest.mark.asyncio
class TestSystemOperations:
    @pytest.mark.parametrize("size", range(34, 65))
    async def test_revert(self, system_operations, size):
        # reason = 0x abcdefghijklmnopqrstuvwxyzABCDEF
        reason = int(string.ascii_letters[:32].encode().hex(), 16)
        reason_low, reason_high = int_to_uint256(reason)
        # The current implementation takes the 31 first bytes of the last 32 bytes
        with kakarot_error(string.ascii_letters[: (size - 32 - 1)][-31:]):
            await system_operations.test__exec_revert(
                reason_low, reason_high, size
            ).call()

    async def test_return(self, system_operations):
        await system_operations.test__exec_return_should_return_context_with_updated_return_data(
            1000
        ).call()

    async def test_call(
        self, system_operations, contract_account_class, account_registry
    ):
        await system_operations.test__exec_call__should_return_a_new_context_based_on_calling_ctx_stack(
            contract_account_class.class_hash, account_registry.contract_address
        ).call()

        await system_operations.test__exec_callcode__should_return_a_new_context_based_on_calling_ctx_stack(
            contract_account_class.class_hash, account_registry.contract_address
        ).call()

        await system_operations.test__exec_staticcall__should_return_a_new_context_based_on_calling_ctx_stack(
            contract_account_class.class_hash, account_registry.contract_address
        ).call()

        await system_operations.test__exec_delegatecall__should_return_a_new_context_based_on_calling_ctx_stack(
            contract_account_class.class_hash, account_registry.contract_address
        ).call()

    async def test_create(
        self, system_operations, contract_account_class, account_registry
    ):
        await system_operations.test__exec_create__should_return_a_new_context_with_bytecode_from_memory_at_empty_address(
            contract_account_class.class_hash,
            account_registry.contract_address,
        ).call()

    async def test_create2(
        self, system_operations, contract_account_class, account_registry
    ):
        # we store a memory word in memory
        # and have our bytecode as the memory read from an offset and size
        # we take that word at an offset and size and use it as the bytecode to determine the expected create2 evm contract address
        # bytecode should be 0x 44 55 66 77
        memory_word = 0x11223344556677880000000000000000
        offset = 3
        size = 4
        salt = 5
        padded_salt = salt.to_bytes(32, byteorder="big")
        evm_caller_address_int = 15
        evm_caller_address_bytes = evm_caller_address_int.to_bytes(20, byteorder="big")
        evm_caller_address = to_checksum_address(evm_caller_address_bytes)
        bytecode = to_bytes(memory_word)[offset : offset + size]

        expected_create2_addr = get_create2_address(
            evm_caller_address, padded_salt, bytecode
        )

        await system_operations.test__exec_create2__should_return_a_new_context_with_bytecode_from_memory_at_expected_address(
            contract_account_class.class_hash,
            account_registry.contract_address,
            evm_caller_address_int,
            (offset, 0),
            (size, 0),
            (salt, 0),
            (0, memory_word),
            from_bytes(decode_hex(expected_create2_addr)),
        ).call()

    async def test_selfdestruct(
        self, system_operations, contract_account_class, account_registry, eth
    ):
        await system_operations.test__exec_selfdestruct__should_delete_account_bytecode(
            eth.contract_address,
            contract_account_class.class_hash,
            account_registry.contract_address,
        ).call()
