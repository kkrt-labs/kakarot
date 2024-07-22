from hashlib import sha256 as py_sha256

import pytest
from hypothesis import given, settings
from hypothesis.strategies import binary


@pytest.mark.SHA256
class TestSHA256:
    @pytest.mark.slow
    @given(message_bytes=binary(min_size=1, max_size=56))
    @settings(max_examples=10)
    def test_sha256_should_return_correct_hash(self, cairo_run, message_bytes):
        # Hash with SHA256
        m = py_sha256()
        m.update(message_bytes)
        expected_hash = m.hexdigest()

        precompile_hash = cairo_run("test__sha256", data=list(message_bytes))
        assert precompile_hash == list(bytes.fromhex(expected_hash))
