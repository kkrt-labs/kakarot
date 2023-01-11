import random

import pytest
import pytest_asyncio
from Crypto.Hash import RIPEMD160
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
    @pytest.mark.parametrize("msg_len", [random.randint(1, 200) for _ in range(3)])
    async def test_ripemd160_should_return_correct_hash(self, ripemd160, msg_len):

        # Build message to be hashed
        message_bytes = bytearray([random.randint(0, 255) for _ in range(msg_len)])

        # Hash with RIPEMD-160
        ripemd160_crypto = RIPEMD160.new()
        ripemd160_crypto.update(message_bytes)
        hash = ripemd160_crypto.hexdigest()

        # Build byte array from hash to compare to precompile result
        expected_result_byte_array = [0] * 12 + list(bytes.fromhex(hash))

        # Build bytes array to pass it through precompile
        bytes_array = [elem for elem in message_bytes]

        precompile_hash = (await ripemd160.test__ripemd160(bytes_array).call()).result[
            0
        ]
        assert expected_result_byte_array == precompile_hash
