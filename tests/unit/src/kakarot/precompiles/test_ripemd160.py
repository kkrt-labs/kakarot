import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def ripemd160(
    starknet: Starknet,
):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_ripemd160.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
class TestRIPEMD160:
    @pytest.mark.parametrize(
        "msg, expected_result", [
            ("a", "0000000000000000000000000bdc9d2d256b3ee9daae347be6f4dc835a467ffe"),
            (
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopqabcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                "00000000000000000000000069a155bddf855b0973a0791d5b7a3326fb83e163"
            ),
        ]
    )
    async def test_ripemd160_should_return_correct_hash(self, ripemd160, msg, expected_result):
        ascii_msg = [ord(char) for char in msg]
        expected_result_byte_array = list(bytes.fromhex(expected_result))
        hash =  (await ripemd160.test__ripemd160(ascii_msg).call()).result[0]
        assert hash == expected_result_byte_array
