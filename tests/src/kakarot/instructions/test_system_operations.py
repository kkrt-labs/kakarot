import string
from typing import Union

import pytest
import pytest_asyncio
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
    async def _factory(evm_address: Union[int, str], value: int):
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

    class TestCreate:
        @pytest.mark.parametrize("nonce", [0, 127, 256, 2**55 - 1])
        async def test_create_has_deterministic_address(self, system_operations, nonce):
            evm_caller_address = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
            expected_create_addr = get_create_address(evm_caller_address, nonce)

            await system_operations.test__get_create_address_should_construct_address_deterministically(
                evm_caller_address,
                nonce,
                int(expected_create_addr, 16),
            ).call()

        @pytest.mark.parametrize("opcode", [0xF0, 0xF5])
        async def test_create(self, system_operations, eth, opcode):
            salt = 5
            evm_caller_address = 0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266
            bytecode = [0xAA, 0xBB, 0xCC, 0xDD]

            starknet_contract_address = (
                await system_operations.compute_starknet_address(
                    evm_caller_address
                ).call()
            ).result.contract_address
            await eth.mint(starknet_contract_address, int_to_uint256(1)).execute()

            (create_address, nonce) = (
                await system_operations.test__exec_create(
                    opcode=opcode,
                    salt=salt,
                    create_code=bytecode,
                    value=1,
                    evm_caller_address=evm_caller_address,
                ).call()
            ).result

            if opcode == 0xF0:
                assert create_address == int(
                    get_create_address(evm_caller_address, nonce), 16
                )
            else:
                assert create_address == int(
                    get_create2_address(evm_caller_address, salt, bytes(bytecode)), 16
                )
