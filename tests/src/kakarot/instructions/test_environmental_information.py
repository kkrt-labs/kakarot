import random

import pytest
import pytest_asyncio
from Crypto.Hash import keccak
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def environmental_information(
    starknet: Starknet, contract_account_class, account_proxy_class
):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/instructions/test_environmental_information.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            contract_account_class.class_hash,
            account_proxy_class.class_hash,
        ],
    )


@pytest.mark.asyncio
class TestEnvironmentalInformation:
    async def test_address(
        self,
        environmental_information,
    ):
        await environmental_information.test__exec_address__should_push_address_to_stack().call()

    async def test_extcodesize(
        self,
        environmental_information,
    ):
        await environmental_information.test__exec_extcodesize__should_handle_address_with_no_code().call()

    async def test_extcodecopy_should_handle_address_with_no_code(
        self,
        environmental_information,
    ):
        await environmental_information.test__exec_extcodecopy__should_handle_address_with_no_code().call()
        await environmental_information.test__returndatacopy().call()

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
        ids=["size_is_bytecodelen-1", "size_is_bytecodelen+1", "offset_is_bytecodelen"],
    )
    async def test_excodecopy_should_handle_address_with_code(
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
            bytecode,
            size=size,
            offset=offset,
            dest_offset=dest_offset,
        ).call()

        memory_result = res.result.memory

        expected = (bytecode + [0] * (offset + size))[offset : (offset + size)]

        assert memory_result == expected

    async def test_gasprice(self, environmental_information):
        await environmental_information.test__exec_gasprice().call()

    @pytest.mark.skip("skipped because not handled currently")
    async def test_extcodehash__should_handle_invalid_address(
        self,
        environmental_information,
    ):
        await environmental_information.test__exec_extcodehash__should_handle_invalid_address().call()

    async def test_excodehash__should_handle_address_with_code(
        self,
        environmental_information,
    ):
        random.seed(0)
        bytecode = [random.randint(0, 255) for _ in range(32)]
        keccak_hash = keccak.new(digest_bits=256)
        keccak_hash.update(bytearray(bytecode))
        expected_hash = int.from_bytes(keccak_hash.digest(), byteorder="big")
        expected_hash_low = expected_hash % (2**128)
        expected_hash_high = expected_hash >> 128

        await environmental_information.test__exec_extcodehash__should_handle_address_with_code(
            bytecode,
            expected_hash_low=expected_hash_low,
            expected_hash_high=expected_hash_high,
        ).call()
