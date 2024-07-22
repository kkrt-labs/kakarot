from typing import cast

import pytest
from eth._utils.blake2.compression import TMessageBlock, blake2b_compress
from hypothesis import given, settings
from hypothesis.strategies import integers, lists

from tests.utils.helpers import pack_64_bits_little


@pytest.mark.slow
@pytest.mark.BLAKE2F
class TestBlake2f:
    def test_should_fail_when_input_len_is_not_213(self, cairo_run):
        output = cairo_run("test_should_fail_when_input_is_not_213")
        assert bytes(output) == b"Precompile: wrong input_len"

    def test_should_fail_when_flag_is_not_0_or_1(self, cairo_run):
        output = cairo_run("test_should_fail_when_flag_is_not_0_or_1")
        assert bytes(output) == b"Precompile: flag error"

    @pytest.mark.parametrize("f", [0, 1])
    @given(
        rounds=integers(min_value=1, max_value=19),
        h=lists(integers(min_value=0, max_value=2**8 - 1), min_size=64, max_size=64),
        m=lists(integers(min_value=0, max_value=2**8 - 1), min_size=128, max_size=128),
        t0=integers(min_value=0, max_value=2**64 - 1),
        t1=integers(min_value=0, max_value=2**64 - 1),
    )
    @settings(max_examples=5, deadline=None)
    def test_should_return_blake2f_compression(
        self, cairo_run, f, rounds, h, m, t0, t1
    ):
        h_starting_state = [
            pack_64_bits_little(h[i * 8 : (i + 1) * 8]) for i in range(8)
        ]

        # When
        output = cairo_run(
            "test_should_return_blake2f_compression",
            rounds=rounds,
            h=h,
            m=m,
            t0=t0,
            t1=t1,
            f=f,
        )

        # Then
        compress = blake2b_compress(
            rounds, cast(TMessageBlock, h_starting_state), m, (t0, t1), bool(f)
        )
        expected = [int(x) for x in compress]
        assert output == expected
