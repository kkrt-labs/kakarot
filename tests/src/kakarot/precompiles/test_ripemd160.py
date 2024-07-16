import random

import pytest
from Crypto.Hash import RIPEMD160


@pytest.fixture(scope="module", params=[pytest.param(1, marks=pytest.mark.slow)])
def msg_bytes(request):
    random.seed(request.param)
    msg_len = random.randint(1, 200)
    return bytearray([random.randint(0, 255) for _ in range(msg_len)])


@pytest.mark.asyncio
class TestRIPEMD160:
    async def test_ripemd160_should_return_correct_hash(self, cairo_run, msg_bytes):
        precompile_hash = cairo_run("test__ripemd160", msg=list(msg_bytes))

        # Hash with RIPEMD-160 to compare with precompile result
        ripemd160_crypto = RIPEMD160.new()
        ripemd160_crypto.update(msg_bytes)
        expected_hash = ripemd160_crypto.hexdigest()
        expected_result_byte_array = [0] * 12 + list(bytes.fromhex(expected_hash))

        assert expected_result_byte_array == precompile_hash
