import pytest
from Crypto.Hash import RIPEMD160
from hypothesis import given, settings
from hypothesis.strategies import binary


@pytest.mark.asyncio
@pytest.mark.slow
class TestRIPEMD160:
    @given(msg_bytes=binary(min_size=1, max_size=200))
    @settings(max_examples=3)
    async def test_ripemd160_should_return_correct_hash(self, cairo_run, msg_bytes):
        precompile_hash = cairo_run("test__ripemd160", msg=list(msg_bytes))

        # Hash with RIPEMD-160 to compare with precompile result
        ripemd160_crypto = RIPEMD160.new()
        ripemd160_crypto.update(msg_bytes)
        expected_hash = ripemd160_crypto.hexdigest()

        assert expected_hash.rjust(64, "0") == bytes(precompile_hash).hex()
