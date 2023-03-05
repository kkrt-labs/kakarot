import string

import pytest
import pytest_asyncio
from eth_utils import decode_hex, to_bytes, to_checksum_address
from starkware.python.utils import from_bytes
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error
from tests.utils.helpers import get_create2_address, get_create_address
from tests.utils.uint256 import int_to_uint256

ZERO_ACCOUNT = "0x0000000000000000000000000000000000000000"


@pytest_asyncio.fixture(scope="module")
async def system_operations(
    starknet: Starknet, eth, contract_account_class, account_proxy_class
):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/instructions/test_system_operations.cairo",
        cairo_path=["src"],
        constructor_calldata=[
            eth.contract_address,
            contract_account_class.class_hash,
            account_proxy_class.class_hash,
        ],
        disable_hint_validation=True,
    )


@pytest_asyncio.fixture(scope="module")
async def mint(system_operations, eth):
    # mint tokens to the 0x0 evm contract address
    sender = int(get_create_address(ZERO_ACCOUNT, 0), 16)
    starket_contract_address = (
        await system_operations.compute_starknet_address(sender).call()
    ).result.contract_address
    await eth.mint(starket_contract_address, (2, 0)).execute()


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

    @pytest.mark.usefixtures("mint")
    async def test_call(self, system_operations):
        await system_operations.test__exec_call__should_return_a_new_context_based_on_calling_ctx_stack().call(
            system_operations.contract_address
        )

        await system_operations.test__exec_callcode__should_return_a_new_context_based_on_calling_ctx_stack().call()

        await system_operations.test__exec_staticcall__should_return_a_new_context_based_on_calling_ctx_stack().call()

        await system_operations.test__exec_delegatecall__should_return_a_new_context_based_on_calling_ctx_stack().call()

    @pytest.mark.usefixtures("mint")
    async def test_call__should_transfer_value(self, system_operations):
        await system_operations.test__exec_call__should_transfer_value().call(
            system_operations.contract_address
        )

    @pytest.mark.parametrize("salt", [127, 256, 2**55 - 1])
    async def test_create(self, system_operations, salt):
        evm_caller_address_int = 15
        evm_caller_address_bytes = evm_caller_address_int.to_bytes(20, byteorder="big")
        evm_caller_address = to_checksum_address(evm_caller_address_bytes)
        expected_create_addr = get_create_address(evm_caller_address, salt)

        await system_operations.test__exec_create__should_return_a_new_context_with_bytecode_from_memory_at_expected_address(
            evm_caller_address_int,
            salt,
            from_bytes(decode_hex(expected_create_addr)),
        ).call()

    async def test_create2(self, system_operations):
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
            evm_caller_address_int,
            (offset, 0),
            (size, 0),
            (salt, 0),
            (0, memory_word),
            from_bytes(decode_hex(expected_create2_addr)),
        ).call()

    async def test_selfdestruct(self, system_operations):
        await system_operations.test__exec_selfdestruct__should_delete_account_bytecode().call(
            system_operations.contract_address
        )
