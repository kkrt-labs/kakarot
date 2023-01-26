import random
from hashlib import sha256 as py_sha256

import pytest
import pytest_asyncio
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def sha256(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/unit/src/kakarot/precompiles/test_sha256.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.SHA256
class TestSHA256:
    async def test_sha256_hello_world_should_return_correct_hash(self, sha256):

        # Build message to be hashed
        message = "hello world"
        message_bytes = message.encode()

        # Hash with SHA256
        m = py_sha256()
        m.update(message_bytes)
        hash = m.hexdigest()

        # Build byte array from hash to compare to precompile result
        expected_result_byte_array = list(bytes.fromhex(hash))

        # Build bytes array to pass through precompile
        bytes_array = [elem for elem in bytearray(message_bytes)]
        precompile_hash = (await sha256.test__sha256(bytes_array).call()).result[0]
        assert precompile_hash == expected_result_byte_array

    @pytest.mark.parametrize("data", [random.randint(1, 56) for _ in range(3)])
    async def test_sha256_should_return_correct_hash(self, sha256, data):

        # Build message to be hashed
        message_bytes = bytearray([random.randint(0, 255) for _ in range(data)])

        # Hash with SHA256
        m = py_sha256()
        m.update(message_bytes)
        hash = m.hexdigest()

        # Build byte array from hash to compare to precompile result
        expected_result_byte_array = list(bytes.fromhex(hash))

        # Build bytes array to pass through precompile
        bytes_array = [elem for elem in bytearray(message_bytes)]
        precompile_hash = (await sha256.test__sha256(bytes_array).call()).result[0]
        assert precompile_hash == expected_result_byte_array
