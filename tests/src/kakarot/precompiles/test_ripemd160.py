import random

import pytest
import pytest_asyncio
from Crypto.Hash import RIPEMD160
from starkware.starknet.testing.starknet import Starknet


@pytest.fixture(scope="module", params=[1])
def msg_bytes(request):
    random.seed(request.param)
    msg_len = random.randint(1, 200)
    return bytearray([random.randint(0, 255) for _ in range(msg_len)])


@pytest_asyncio.fixture(scope="module")
async def ripemd160(
    starknet: Starknet,
):
    class_hash = await starknet.deprecated_declare(
        source="./tests/src/kakarot/precompiles/test_ripemd160.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(class_hash=class_hash.class_hash)


@pytest.mark.asyncio
class TestRIPEMD160:
    async def test_ripemd160_should_return_correct_hash(self, ripemd160, msg_bytes):
        # Build message to be hashed

        # Hash with RIPEMD-160
        ripemd160_crypto = RIPEMD160.new()
        ripemd160_crypto.update(msg_bytes)
        hash = ripemd160_crypto.hexdigest()

        # Build byte array from hash to compare to precompile result
        expected_result_byte_array = [0] * 12 + list(bytes.fromhex(hash))

        # Build bytes array to pass it through precompile
        bytes_array = [elem for elem in msg_bytes]

        precompile_hash = (await ripemd160.test__ripemd160(bytes_array).call()).result[
            0
        ]
        assert expected_result_byte_array == precompile_hash
