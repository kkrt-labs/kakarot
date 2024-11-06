import pytest
from Crypto.Hash import RIPEMD160
from hypothesis import example, given
from hypothesis.strategies import binary

from tests.utils.errors import cairo_error
from tests.utils.hints import insert_hint


@pytest.mark.asyncio
@pytest.mark.slow
class TestRIPEMD160:
    @given(msg_bytes=binary(min_size=1, max_size=200))
    @example(
        msg_bytes=b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmomnopnopq"
    )  # https://github.com/code-423n4/2024-09-kakarot-findings/issues/50
    async def test_ripemd160_should_return_correct_hash(self, cairo_run, msg_bytes):
        precompile_hash = cairo_run("test__ripemd160", msg=list(msg_bytes))

        # Hash with RIPEMD-160 to compare with precompile result
        ripemd160_crypto = RIPEMD160.new()
        ripemd160_crypto.update(msg_bytes)
        expected_hash = ripemd160_crypto.hexdigest()

        assert expected_hash.rjust(64, "0") == bytes(precompile_hash).hex()

    # see https://github.com/code-423n4/2024-09-kakarot-findings/issues/54
    # see https://github.com/code-423n4/2024-09-kakarot-findings/issues/21
    async def test_finalized_dict_ripemd160(self, cairo_program, cairo_run):
        msg_bytes = bytes([0x00] * 57)
        with (
            insert_hint(
                cairo_program,
                "ripemd160.cairo:161",
                "try:\n"
                "    dict_tracker = __dict_manager.get_tracker(ids.dict_ptr)\n"
                "    dict_tracker.data[ids.index_4] = 1\n"
                "except Exception: pass\n",
            ),
            cairo_error(
                message="An ASSERT_EQ instruction failed"
            ),  # fails with an assertion error from default_dict_finalize_inner
        ):
            cairo_run("test__ripemd160", msg=list(msg_bytes))
