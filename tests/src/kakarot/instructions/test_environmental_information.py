import random

import pytest
from Crypto.Hash import keccak
from starkware.starknet.public.abi import get_selector_from_name

from tests.utils.helpers import pack_into_u64_words
from tests.utils.syscall_handler import SyscallHandler
from tests.utils.uint256 import int_to_uint256

EXISTING_ACCOUNT = 0xABDE1
EXISTING_ACCOUNT_SN_ADDR = 0x1234
NON_EXISTING_ACCOUNT = 0xDEAD
CAIRO1_HELPERS_CLASS_HASH = 0xDEADBEEFABDE1


@pytest.fixture(scope="module", params=[0, 32], ids=["no bytecode", "32 bytes"])
def bytecode(request):
    random.seed(0)
    return [random.randint(0, 255) for _ in range(request.param)]


@pytest.fixture(scope="module")
def bytecode_hash(bytecode):
    keccak_hash = keccak.new(digest_bits=256)
    keccak_hash.update(bytearray(bytecode))
    return int.from_bytes(keccak_hash.digest(), byteorder="big")


@pytest.fixture(
    scope="module",
    params=[EXISTING_ACCOUNT, NON_EXISTING_ACCOUNT],
    ids=["existing", "non existing"],
)
def address(request):
    return request.param


class TestEnvironmentalInformation:
    class TestAddress:
        def test_should_push_address(self, cairo_run):
            cairo_run("test__exec_address__should_push_address_to_stack")

    class TestExtCodeSize:
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [1])
        @SyscallHandler.patch(
            "Kakarot_evm_to_starknet_address", EXISTING_ACCOUNT, 0x1234
        )
        def test_extcodesize_should_push_code_size(self, cairo_run, bytecode, address):
            with SyscallHandler.patch(
                "IAccount.bytecode", lambda addr, data: [len(bytecode), *bytecode]
            ):
                output = cairo_run("test__exec_extcodesize", address=address)

            assert output == hex(len(bytecode) if address == EXISTING_ACCOUNT else 0)

    class TestExtCodeCopy:
        @pytest.mark.parametrize(
            "case",
            [
                {
                    "size": 31,
                    "offset": 0,
                    "dest_offset": 0,
                },
                {
                    "size": 33,
                    "offset": 0,
                    "dest_offset": 0,
                },
                {
                    "size": 1,
                    "offset": 32,
                    "dest_offset": 0,
                },
            ],
            ids=[
                "size_is_bytecodelen-1",
                "size_is_bytecodelen+1",
                "offset_is_bytecodelen",
            ],
        )
        @SyscallHandler.patch("IERC20.balanceOf", lambda addr, data: [0, 1])
        @SyscallHandler.patch("IAccount.get_nonce", lambda addr, data: [1])
        @SyscallHandler.patch(
            "Kakarot_evm_to_starknet_address", EXISTING_ACCOUNT, 0x1234
        )
        def test_extcodecopy_should_copy_code(self, cairo_run, case, bytecode, address):
            size = case["size"]
            offset = case["offset"]
            dest_offset = case["dest_offset"]

            with SyscallHandler.patch(
                "IAccount.bytecode", lambda addr, data: [len(bytecode), *bytecode]
            ):
                memory = cairo_run(
                    "test__exec_extcodecopy",
                    size=size,
                    offset=offset,
                    dest_offset=dest_offset,
                    address=address,
                )

            deployed_bytecode = bytecode if address == EXISTING_ACCOUNT else []
            copied_bytecode = bytes(
                # bytecode is padded with surely enough 0 and then sliced
                (deployed_bytecode + [0] * (offset + size))[offset : offset + size]
            )
            assert (
                bytes.fromhex(memory)[dest_offset : dest_offset + size]
                == copied_bytecode
            )

    class TestGasPrice:
        def test_gasprice(self, cairo_run):
            cairo_run("test__exec_gasprice")

    class TestExtCodeHash:
        @SyscallHandler.patch(
            "IERC20.balanceOf",
            lambda sn_addr, data: (
                [0, 1] if sn_addr == EXISTING_ACCOUNT_SN_ADDR else [0, 0]
            ),
        )
        @SyscallHandler.patch(
            "IAccount.get_nonce",
            lambda sn_addr, data: [1] if sn_addr == EXISTING_ACCOUNT_SN_ADDR else [0],
        )
        @SyscallHandler.patch(
            "Kakarot_evm_to_starknet_address",
            EXISTING_ACCOUNT,
            EXISTING_ACCOUNT_SN_ADDR,
        )
        @SyscallHandler.patch(
            "Kakarot_cairo1_helpers_class_hash",
            CAIRO1_HELPERS_CLASS_HASH,
        )
        def test_extcodehash__should_push_hash(
            self, cairo_run, bytecode, bytecode_hash, address
        ):
            with SyscallHandler.patch(
                "IAccount.bytecode", lambda sn_addr, data: [len(bytecode), *bytecode]
            ), SyscallHandler.patch(
                "ICairo1Helpers.library_call_keccak",
                lambda class_hash, data: int_to_uint256(bytecode_hash),
            ):
                output = cairo_run("test__exec_extcodehash", address=address)

            if address == EXISTING_ACCOUNT:
                (
                    len_full_words,
                    full_words,
                    last_expected_word,
                    last_expected_word_bytes_used,
                ) = pack_into_u64_words(bytecode)
                SyscallHandler.mock_library_call.assert_any_call(
                    class_hash=CAIRO1_HELPERS_CLASS_HASH,
                    function_selector=get_selector_from_name("keccak"),
                    calldata=[
                        len_full_words,
                        *full_words,
                        last_expected_word,
                        last_expected_word_bytes_used,
                    ],
                )
                assert output == hex(bytecode_hash)
            else:
                assert output == "0x0"
