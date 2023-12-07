import string

import pytest
import pytest_asyncio
from eth_utils import to_bytes, to_checksum_address
from starkware.starknet.testing.starknet import Starknet

from tests.utils.helpers import get_create2_address, get_create_address
from tests.utils.uint256 import int_to_uint256

ZERO_ACCOUNT = "0x0000000000000000000000000000000000000000"


@pytest_asyncio.fixture(scope="module")
async def system_operations(
    starknet: Starknet, eth, contract_account_class, account_proxy_class
):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_system_operations.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            eth.contract_address,
            contract_account_class.class_hash,
            account_proxy_class.class_hash,
        ],
    )


@pytest_asyncio.fixture(scope="module")
async def mint(system_operations, eth):
    async def _factory(evm_address: str, value: int):
        # mint tokens to the provided evm address
        sender = int(get_create_address(evm_address, 0), 16)
        starknet_contract_address = (
            await system_operations.compute_starknet_address(sender).call()
        ).result.contract_address
        await eth.mint(starknet_contract_address, int_to_uint256(value)).execute()

    return _factory


@pytest.mark.asyncio
class TestSystemOperations:
    @pytest.mark.parametrize("size", range(34, 65))
    async def test_revert(self, system_operations, size):
        # reason = 0x abcdefghijklmnopqrstuvwxyzABCDEF
        reason = string.ascii_letters[:32].encode()
        reason_low, reason_high = int_to_uint256(int(reason.hex(), 16))
        revert_reason = await system_operations.test__exec_revert(
            reason_low, reason_high, size
        ).call()
        expected_revert_reason = ([0] * 32 + list(reason) + [0] * 32)[:size]
        assert revert_reason.result[0] == expected_revert_reason

    async def test_return(self, system_operations):
        await system_operations.test__exec_return_should_return_context_with_updated_return_data(
            1000
        ).call()

    class TestCall:
        async def test_should_return_a_new_context_based_on_calling_ctx_stack(
            self, system_operations, mint
        ):
            await mint(ZERO_ACCOUNT, 2)
            await system_operations.test__exec_call__should_return_a_new_context_based_on_calling_ctx_stack().call(
                system_operations.contract_address
            )

        async def test_should_transfer_value(self, system_operations, mint):
            await mint(ZERO_ACCOUNT, 2)
            await system_operations.test__exec_call__should_transfer_value().call(
                system_operations.contract_address
            )

    class TestCallcode:
        async def test_should_return_a_new_context_based_on_calling_ctx_stack(
            self, system_operations, mint
        ):
            await mint(ZERO_ACCOUNT, 2)
            await system_operations.test__exec_callcode__should_return_a_new_context_based_on_calling_ctx_stack().call(
                system_operations.contract_address
            )

        async def test_should_transfer_value(self, system_operations, mint):
            await mint(ZERO_ACCOUNT, 2)
            await system_operations.test__exec_callcode__should_transfer_value().call(
                system_operations.contract_address
            )

    class TestStaticcall:
        async def test_should_return_a_new_context_based_on_calling_ctx_stack(
            self, system_operations, mint
        ):
            await mint(ZERO_ACCOUNT, 2)
            await system_operations.test__exec_staticcall__should_return_a_new_context_based_on_calling_ctx_stack().call()

    class TestDelegatecall:
        async def test_should_return_a_new_context_based_on_calling_ctx_stack(
            self, system_operations, mint
        ):
            await mint(ZERO_ACCOUNT, 2)
            await system_operations.test__exec_delegatecall__should_return_a_new_context_based_on_calling_ctx_stack().call()

    @pytest.mark.parametrize("nonce", [0, 127, 256, 2**55 - 1])
    async def test_create_has_deterministic_address(self, system_operations, nonce):
        # given we start with the first anvil test account
        evm_caller_address = to_checksum_address(
            0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        )
        expected_create_addr = get_create_address(evm_caller_address, nonce)

        await system_operations.test__get_create_address_should_construct_address_deterministically(
            int(evm_caller_address, 16),
            nonce,
            int(expected_create_addr, 16),
        ).call()

    async def test_create(self, system_operations, eth):
        salt = 0
        # given we start with the first anvil test account
        evm_caller_address = to_checksum_address(
            0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        )
        expected_create_addr = get_create_address(evm_caller_address, salt)

        starknet_contract_address = (
            await system_operations.compute_starknet_address(
                int(evm_caller_address, 16)
            ).call()
        ).result.contract_address
        await eth.mint(starknet_contract_address, int_to_uint256(1)).execute()

        await system_operations.test__exec_create__should_return_a_new_context_with_bytecode_from_memory_at_expected_address(
            int(evm_caller_address, 16),
            salt,
            int(expected_create_addr, 16),
        ).call()

    async def test_create2(self, system_operations, eth):
        # we store a memory word in memory
        # and have our bytecode as the memory read from an offset and size
        # we take that word at an offset and size and use it as the bytecode to determine the expected create2 evm contract address
        # bytecode should be 0x 44 55 66 77
        memory_word = 0x11223344556677880000000000000000
        offset = 3
        size = 4
        salt = 5
        padded_salt = salt.to_bytes(32, byteorder="big")
        evm_caller_address = to_checksum_address(
            0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
        )
        bytecode = to_bytes(memory_word)[offset : offset + size]

        starknet_contract_address = (
            await system_operations.compute_starknet_address(
                int(evm_caller_address, 16)
            ).call()
        ).result.contract_address
        await eth.mint(starknet_contract_address, int_to_uint256(1)).execute()

        expected_create2_addr = get_create2_address(
            evm_caller_address, padded_salt, bytecode
        )

        await system_operations.test__exec_create2__should_return_a_new_context_with_bytecode_from_memory_at_expected_address(
            int(evm_caller_address, 16),
            offset,
            size,
            salt,
            (0, memory_word),
            int(expected_create2_addr, 16),
        ).call()
