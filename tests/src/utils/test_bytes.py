import pytest

from tests.utils.uint256 import int_to_uint256

PRIME = 0x800000000000011000000000000000000000000000000000000000000000001


class TestBytes:
    class TestFeltToAscii:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF])
        def test_should_return_ascii(self, cairo_run, n):
            output = cairo_run("test__felt_to_ascii", n=n)
            assert str(n) == bytes(output).decode()

    class TestFeltToBytesLittle:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        def test_should_return_bytes(self, cairo_run, n):
            output = cairo_run("test__felt_to_bytes_little", n=n)
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0"))[::-1] == res

    class TestFeltToBytes:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        def test_should_return_bytes(self, cairo_run, n):
            output = cairo_run("test__felt_to_bytes", n=n)
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0")) == res

    class TestFeltToBytes20:
        @pytest.mark.parametrize("n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1])
        def test_should_return_bytes20(self, cairo_run, n):
            output = cairo_run("test__felt_to_bytes20", n=n)
            assert f"{n:064x}"[-40:] == bytes(output).hex()

    class TestUint256ToBytesLittle:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        def test_should_return_bytes(self, cairo_run, n):
            output = cairo_run("test__uint256_to_bytes_little", n=int_to_uint256(n))
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0"))[::-1] == res

    class TestUint256ToBytes:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        def test_should_return_bytes(self, cairo_run, n):
            output = cairo_run("test__uint256_to_bytes", n=int_to_uint256(n))
            res = bytes(output)
            assert bytes.fromhex(f"{n:x}".rjust(len(res) * 2, "0")) == res

    class TestUint256ToBytes32:
        @pytest.mark.parametrize(
            "n", [0, 10, 1234, 0xFFFFFF, 2**128, PRIME - 1, 2**256 - 1]
        )
        def test_should_return_bytes(self, cairo_run, n):
            output = cairo_run("test__uint256_to_bytes32", n=int_to_uint256(n))
            assert bytes.fromhex(f"{n:064x}") == bytes(output)

    class TestBytesToBytes8LittleEndian:

        @pytest.mark.parametrize("bytes_len", list(range(20)))
        def test_should_return_bytes8(self, cairo_run, bytes_len):
            bytes_array = list(range(bytes_len))
            bytes8_little_endian = [
                int.from_bytes(bytes(bytes_array[i : i + 8]), byteorder="little")
                for i in range(0, len(bytes_array), 8)
            ]
            # Case where the last word is not full
            if bytes8_little_endian and not len(bytes_array) % 8 == 0:
                last_expected_word = bytes8_little_endian[-1]
                last_expected_word_bytes_used = (
                    last_expected_word.bit_length() // 8 + 1
                    if last_expected_word
                    else 1
                )
            # Case where the last word is full - or no words at all
            else:
                last_expected_word = 0
                last_expected_word_bytes_used = 0

            output = cairo_run("test__bytes_to_bytes8_little_endian", bytes=bytes_array)

            *full_words, last_word, last_word_num_bytes = output

            if len(bytes_array) % 8 == 0:
                assert bytes8_little_endian == full_words
            else:
                assert bytes8_little_endian[:-1] == full_words
            assert last_expected_word == last_word
            assert last_expected_word_bytes_used == last_word_num_bytes

        @pytest.mark.parametrize(
            "byte_values, expected_words, last_word, last_word_bytes_used",
            [
                ([], [], 0, 0),
                ([0], [], 0, 1),
                ([1, 2, 3, 4, 5, 6, 7, 8], [0x0807060504030201], 0, 0),
                ([1, 2, 3, 4, 5, 6, 7, 8, 9], [0x0807060504030201], 9, 1),
            ],
        )
        def test_should_return_bytes8_specific_inputs(
            self,
            cairo_run,
            byte_values,
            expected_words,
            last_word,
            last_word_bytes_used,
        ):
            output = cairo_run("test__bytes_to_bytes8_little_endian", bytes=byte_values)
            *full_words, last_word_result, last_word_num_bytes = output
            assert (
                expected_words == full_words
            ), f"Expected full words: {expected_words}, but got: {full_words}"
            assert (
                last_word == last_word_result
            ), f"Expected last word: {last_word}, but got: {last_word_result}"
            assert (
                last_word_bytes_used == last_word_num_bytes
            ), f"Expected last word bytes used: {last_word_bytes_used}, but got: {last_word_num_bytes}"
