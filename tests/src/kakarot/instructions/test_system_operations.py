import pytest
from eth_account.account import Account
from eth_utils import keccak

from tests.utils.constants import CHAIN_ID
from tests.utils.helpers import generate_random_private_key
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256

NONCE = 1
MAGIC = 0x04


@pytest.fixture
def private_key():
    return generate_random_private_key()


@pytest.fixture
def invoker_address(private_key):
    return int(private_key.public_key.to_checksum_address(), 16)


@pytest.fixture
def message(invoker_address):
    return {
        "MAGIC": MAGIC.to_bytes(1, "big"),
        "chainId": CHAIN_ID.to_bytes(32, "big"),
        "nonce": NONCE.to_bytes(32, "big"),
        "invokerAddress": invoker_address.to_bytes(32, "big"),
        "commit": "commit".encode("utf-8").ljust(32, b"\x00"),
    }


def prepare_stack_and_memory(invoker_address, message, private_key):
    serialized_msg = b"".join(message.values())
    msg_hash = keccak(serialized_msg)
    (messageHash, r, s, v, signature) = Account.signHash(msg_hash, private_key)
    yParity = v - 27

    addr_low, addr_high = int_to_uint256(invoker_address)
    stack = [[addr_low, addr_high], [0, 0], [97, 0]]  # len, offset, invoker_address

    offset = 0
    memory = []
    memory[offset : offset + 1] = [yParity]
    memory[offset + 1 : offset + 33] = r.to_bytes(32, "big")
    memory[offset + 33 : offset + 65] = s.to_bytes(32, "big")
    memory[offset + 65 : offset + 97] = message["commit"]

    return stack, memory


class TestSystemOperations:
    class TestAuth:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__exec_auth__should_pass_valid_signature(
            self, cairo_run, private_key, invoker_address, message
        ):
            stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x1"]
            assert evm["message"]["authorized"] == {
                "is_some": 1,
                "value": invoker_address,
            }

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE + 1])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__exec_auth__should_fail_invalid_nonce(
            self, cairo_run, private_key, invoker_address, message
        ):
            stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__exec_auth__should_fail_invalid_invoker(
            self, cairo_run, private_key, invoker_address, message
        ):
            invoker_address += 1
            stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__exec_auth__should_fail_invalid_chainid(
            self, cairo_run, private_key, invoker_address, message
        ):
            message["chainId"] = (CHAIN_ID + 1).to_bytes(32, "big")
            stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

        # Test for invalid commit
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__exec_auth__should_fail_invalid_commit(
            self, cairo_run, private_key, invoker_address, message
        ):
            message["commit"] = "invalid".encode("utf-8").ljust(32, b"\x00")
            stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__exec_auth_invalid_signer_private_key(
            self, cairo_run, invoker_address, message
        ):
            private_key = generate_random_private_key()
            stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

    class TestAuthCall:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__auth_then_authcall_should_return_correct_evm_frame(
            self, cairo_run, private_key, invoker_address, message
        ):
            auth_stack, auth_memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            gas = [100000, 0]
            called_address = 0xC411
            value = [100, 0]
            args_offset = [0, 0]
            args_len = [0, 0]
            ret_offset = [0, 0]
            ret_len = [0, 0]
            authcall_stack = [
                gas,
                list(int_to_uint256(called_address)),
                value,
                args_offset,
                args_len,
                ret_offset,
                ret_len,
            ]
            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                evm = cairo_run(
                    "test__auth_authcall",
                    auth_stack=auth_stack,
                    auth_memory=auth_memory,
                    invoker_address=invoker_address,
                    authcall_stack=authcall_stack,
                )

            assert evm["message"]["authorized"] == {
                "is_some": 0,
                "value": 0,
            }  # Authorized should be None in the new frame
            assert int(evm["message"]["caller"], 16) == invoker_address
            assert int(evm["message"]["value"], 16) == value[0]
            assert int(evm["message"]["address"]["evm"], 16) == called_address

            # Parent frame should keep the authorized value
            assert evm["message"]["parent"]["evm"]["message"]["p"] == {
                "is_some": 1,
                "value": invoker_address,
            }
