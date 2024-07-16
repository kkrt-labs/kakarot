import random
from datetime import timedelta
from hashlib import sha256 as py_sha256

import pytest
from hypothesis import given, settings
from hypothesis.strategies import integers


@pytest.mark.SHA256
class TestSHA256:
    @pytest.mark.slow
    @given(
        data_len=integers(min_value=1, max_value=56),
    )
    @settings(deadline=timedelta(milliseconds=30000), max_examples=10)
    def test_sha256_should_return_correct_hash(self, cairo_run, data_len):
        # Set seed
        random.seed(0)

        # Build message to be hashed
        message_bytes = random.randbytes(data_len)

        # Hash with SHA256
        m = py_sha256()
        m.update(message_bytes)
        expected_hash = m.hexdigest()

        # Build byte array from expected_hash to compare to precompile result
        expected_result_byte_array = list(bytes.fromhex(expected_hash))

        # Build bytes array to pass through precompile
        bytes_array = list(bytearray(message_bytes))
        precompile_hash = cairo_run("test__sha256", data=bytes_array)
        assert precompile_hash == expected_result_byte_array
