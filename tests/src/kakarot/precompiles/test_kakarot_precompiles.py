from hypothesis import given
from hypothesis import strategies as st


class TestKakarotPrecompiles:

    class TestCairoMessage:
        @given(input_=st.binary(min_size=0, max_size=95))
        def test_should_revert_input_to_short(self, cairo_run, input_):
            (output_len, output, reverted, gas_used) = cairo_run(
                "test__cairo_message", input=input_
            )
            assert bytes(output[:output_len]) == b"Kakarot: OutOfBoundsRead"
            assert reverted
            assert gas_used == 5000

        @given(input_=st.binary(min_size=96))
        def test_should_revert_first_word_not_address(self, cairo_run, input_):
            (output_len, output, reverted, gas_used) = cairo_run(
                "test__cairo_message", input=input_
            )
            assert bool(reverted) == (int.from_bytes(input_[:12], "big") != 0)
            if reverted:
                assert bytes(output[:output_len]) == b"Precompile: wrong input_len"
            assert gas_used == 5000

        @given(data_len=st.integers(min_value=0, max_value=2**256 - 1))
        def test_should_revert_data_len_not_bytes4(self, cairo_run, data_len):
            input_ = b"\x00" * 64 + data_len.to_bytes(32, "big")
            (output_len, output, reverted, gas_used) = cairo_run(
                "test__cairo_message", input=input_
            )
            assert bytes(output[:output_len]) == (
                b""
                if data_len == 0
                else (
                    # If the data_len is in bound, the rest of the function fails
                    # due to the data_len being too large wrt the input length.
                    # One could set input_ to b"\x00" * 64 + data_len.to_bytes(32, "big") + data_len * b"\x00"
                    # to avoid this issue but it significantly increases the time to run the test
                    b"Kakarot: OutOfBoundsRead"
                    if (data_len < 2**32)
                    else b"Precompile: wrong input_len"
                )
            )
            assert gas_used == 5000
