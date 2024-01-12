import random

import pytest
from rlp import decode, encode


class TestRLP:
    class TestDecode:
        @pytest.mark.parametrize("payload_len", [55, 56])
        async def test_should_match_decode_reference_implementation(
            self, cairo_run, payload_len
        ):
            random.seed(0)
            data = [random.randbytes(payload_len - 1)]
            encoded_data = encode(data)
            expected_result = decode(encoded_data)

            output = cairo_run("test__decode", data=list(encoded_data), is_list=1)
            output = cairo_run("test__decode", data=output, is_list=0)

            assert expected_result == [bytes(output)]
