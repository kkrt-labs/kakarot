import pytest
from ethereum.crypto.blake2 import Blake2b
from hypothesis import given, settings
from hypothesis.strategies import binary


@pytest.mark.slow
@pytest.mark.BLAKE2F
class TestBlake2f:
    def test_should_fail_when_input_len_is_not_213(self, cairo_run):
        output = cairo_run("test_should_fail_when_input_is_not_213")
        assert bytes(output) == b"Precompile: wrong input_len"

    def test_should_fail_when_flag_is_not_0_or_1(self, cairo_run):
        output = cairo_run("test_should_fail_when_flag_is_not_0_or_1")
        assert bytes(output) == b"Precompile: flag error"

    @given(data=binary(min_size=213, max_size=213))
    @settings(max_examples=5)
    def test_should_return_blake2f_compression(self, cairo_run, data):
        # The first 4 bytes are the number of rounds, so we just limit this to 3 rounds at most
        # to save time
        # The 213th byte is the flag, so we limit it to 0 or 1
        data = (
            (int.from_bytes(data[:4], "big") % 3).to_bytes(4, "big")
            + data[4:212]
            + (data[212] % 2).to_bytes(1, "big")
        )
        output_len, output = cairo_run(
            "test_should_return_blake2f_compression", input=data
        )

        blake2b = Blake2b()
        assert bytes(output[:output_len]) == blake2b.compress(
            *blake2b.get_blake2_parameters(data)
        )
