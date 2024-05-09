import pytest
from eth_account.account import Account
from eth_utils import keccak

from tests.utils.constants import CHAIN_ID
from tests.utils.helpers import generate_random_private_key
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256

NONCE = 1
MAGIC = 0x04
CAIRO1_HELPERS_CLASS_HASH = 0xDEADBEEFABDE1


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
    (_, r, s, v, signature) = Account.signHash(msg_hash, private_key)
    y_parity = v - 27

    stack = [
        int_to_uint256(value)
        for value in [invoker_address, 0, 65 + len(message["commit"])]
    ]  # invoker_address, offset, len

    memory = [
        y_parity,
        *r.to_bytes(32, "big"),
        *s.to_bytes(32, "big"),
        *message["commit"],
    ]

    return serialized_msg, int.from_bytes(msg_hash, "big"), stack, memory


class TestSystemOperations:
    class TestAuth:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        @SyscallHandler.patch(
            "Kakarot_cairo1_helpers_class_hash",
            CAIRO1_HELPERS_CLASS_HASH,
        )
        def test__should_pass_valid_signature(
            self, cairo_run, private_key, invoker_address, message
        ):
            _, _, stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth_with_initial_authority_unset",
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
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__should_fail_invalid_signature(
            self, cairo_run, private_key, invoker_address, message
        ):
            _, _, stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            # Modify a byte in the signature to make it invalid
            memory[0] = 255

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth_with_initial_authority_unset",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [0])
        def test__should_fail_invalid_invoker(
            self, cairo_run, private_key, invoker_address, message
        ):
            invoker_address += 1
            _, _, stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth_with_initial_authority_unset",
                    stack=stack,
                    memory=memory,
                    invoker_address=invoker_address,
                )

            assert stack == ["0x0"]
            assert evm["message"]["authorized"] == {"is_some": 0, "value": 0}

        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [NONCE])
        @SyscallHandler.patch("IAccount.bytecode", lambda addr, data: [3, 0x1, 0x2, 0x3])
        def test__should_fail_authority_has_code(
            self, cairo_run, private_key, invoker_address, message
        ):
            _, _, stack, memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            with SyscallHandler.patch(
                "Kakarot_evm_to_starknet_address", invoker_address, 0x1234
            ):
                stack, evm = cairo_run(
                    "test__auth_with_initial_authority_set",
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
        @SyscallHandler.patch(
            "Kakarot_cairo1_helpers_class_hash",
            CAIRO1_HELPERS_CLASS_HASH,
        )
        def test__should_return_correct_evm_frame(
            self, cairo_run, private_key, invoker_address, message
        ):
            _, _, auth_stack, auth_memory = prepare_stack_and_memory(
                invoker_address, message, private_key
            )

            gas = 100000
            called_address = 0xC411
            value = 100
            args_offset = 0
            args_len = 0
            ret_offset = 0
            ret_len = 0
            authcall_stack = [
                int_to_uint256(value)
                for value in [
                    gas,
                    called_address,
                    value,
                    args_offset,
                    args_len,
                    ret_offset,
                    ret_len,
                ]
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
            assert int(evm["message"]["value"], 16) == value
            assert int(evm["message"]["address"]["evm"], 16) == called_address

            # Parent frame should keep the authorized value
            assert evm["message"]["parent"]["evm"]["message"]["authorized"] == {
                "is_some": 1,
                "value": invoker_address,
            }
