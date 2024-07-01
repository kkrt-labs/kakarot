import os
import random

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

        @pytest.mark.parametrize(
            "bytes_len",
            [
                0,
                10,
                100,
                1000,
                pytest.param(10_000, marks=pytest.mark.slow),
                pytest.param(100_000, marks=pytest.mark.slow),
            ],
        )
        def test_should_return_bytes8(self, cairo_run, bytes_len):
            random.seed(bytes_len)
            bytes_array = list(os.urandom(bytes_len))
            bytes8_little_endian = [
                int.from_bytes(bytes(bytes_array[i : i + 8]), "little")
                for i in range(0, len(bytes_array), 8)
            ]
            output, last_word, last_word_len = cairo_run(
                "test__bytes_to_bytes8_little_endian", bytes=bytes_array
            )
            output = output + [last_word] if last_word_len > 0 else output

            assert bytes8_little_endian == output
