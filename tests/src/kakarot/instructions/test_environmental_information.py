import random

import pytest
import pytest_asyncio
from Crypto.Hash import keccak
from starkware.starknet.testing.starknet import Starknet


@pytest.fixture(scope="module")
def bytecode():
    random.seed(0)
    return [random.randint(0, 255) for _ in range(32)]


@pytest.fixture(scope="module")
def bytecode_hash(bytecode):
    keccak_hash = keccak.new(digest_bits=256)
    keccak_hash.update(bytearray(bytecode))
    return int.from_bytes(keccak_hash.digest(), byteorder="big")


@pytest_asyncio.fixture(scope="module")
async def environmental_information(
    starknet: Starknet, eth, contract_account_class, account_proxy_class, bytecode
):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_environmental_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )

    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            eth.contract_address,
            contract_account_class.class_hash,
            account_proxy_class.class_hash,
            len(bytecode),
            *bytecode,
        ],
    )


@pytest.mark.asyncio
class TestEnvironmentalInformation:
    class TestAddress:
        async def test_should_push_address(self, environmental_information):
            await environmental_information.test__exec_address__should_push_address_to_stack().call()

    class TestExtCodeSize:
        async def test_extcodesize_should_push_code_size(
            self, environmental_information
        ):
            await environmental_information.test__exec_extcodesize__should_handle_address_with_code().call()

        async def test_extcodesize_should_handle_address_with_no_code(
            self, environmental_information
        ):
            await environmental_information.test__exec_extcodesize__should_handle_address_with_no_code().call()

    class TestExtCodeCopy:
        async def test_extcodecopy_should_handle_address_with_no_code(
            self, environmental_information
        ):
            await environmental_information.test__exec_extcodecopy__should_handle_address_with_no_code().call()

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
        async def test_extcodecopy_should_handle_address_with_code(
            self,
            environmental_information,
            case,
        ):
            random.seed(0)
            bytecode = [random.randint(0, 255) for _ in range(32)]

            size = case["size"]
            offset = case["offset"]
            dest_offset = case["dest_offset"]

            res = await environmental_information.test__exec_extcodecopy__should_handle_address_with_code(
                size, offset, dest_offset
            ).call()

            memory_result = res.result.memory

            expected = (bytecode + [0] * (offset + size))[offset : (offset + size)]

            assert memory_result == expected

    class TestGasPrice:
        async def test_gasprice(self, environmental_information):
            await environmental_information.test__exec_gasprice().call()

    class TestExtCodeHash:
        async def test_extcodehash__should_handle_invalid_address(
            self,
            environmental_information,
        ):
            await environmental_information.test__exec_extcodehash__should_handle_invalid_address().call()

        async def test_extcodehash__should_handle_address_with_code(
            self, environmental_information, bytecode_hash
        ):
            expected_hash_low = bytecode_hash % (2**128)
            expected_hash_high = bytecode_hash >> 128

            await environmental_information.test__exec_extcodehash__should_handle_address_with_code(
                expected_hash_low=expected_hash_low,
                expected_hash_high=expected_hash_high,
            ).call()
