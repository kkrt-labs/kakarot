import random
from datetime import timedelta
from hashlib import sha256 as py_sha256

import pytest
import pytest_asyncio
from hypothesis import given, settings
from hypothesis.strategies import integers
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def sha256(starknet: Starknet):
    return await starknet.deploy(
        source="./tests/src/kakarot/precompiles/test_sha256.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )


@pytest.mark.asyncio
@pytest.mark.SHA256
class TestSHA256:
    @given(
        data_len=integers(min_value=1, max_value=56),
    )
    @settings(deadline=timedelta(milliseconds=30000), max_examples=10)
    async def test_sha256_should_return_correct_hash(self, sha256, data_len):
        # Set seed
        random.seed(0)

        # Build message to be hashed
        message_bytes = random.randbytes(data_len)

        # Hash with SHA256
        m = py_sha256()
        m.update(message_bytes)
        hash = m.hexdigest()

        # Build byte array from hash to compare to precompile result
        expected_result_byte_array = list(bytes.fromhex(hash))

        # Build bytes array to pass through precompile
        bytes_array = list(bytearray(message_bytes))
        precompile_hash = (await sha256.test__sha256(bytes_array).call()).result[0]
        assert precompile_hash == expected_result_byte_array
