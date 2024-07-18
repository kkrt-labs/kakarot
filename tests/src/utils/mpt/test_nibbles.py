import pytest
from tests.utils.errors import cairo_error

class TestNibbles:
    class TestFromBytes:
        @pytest.mark.parametrize("data, expected_output", [
            ([0x01, 0xab], [0x0, 0x1, 0xa, 0xb]),
            ([0x12, 0x34], [0x1, 0x2, 0x3, 0x4]),
            ([0xff, 0x00], [0xf, 0xf, 0x0, 0x0]),
            ([0x9a, 0xbc, 0xde], [0x9, 0xa, 0xb, 0xc, 0xd, 0xe]),
            ([], []),
        ])
        def test_should_return_nibbles_from_bytes(self, cairo_run, data, expected_output):
            output = cairo_run("test__from_bytes", data=data)
            assert output == expected_output

    class TestPackNibbles:
        @pytest.mark.parametrize("nibbles, expected_bytes", [
            ([0x0, 0x1, 0xa, 0xb], [0x01, 0xab]),
            ([0x1, 0x2, 0x3, 0x4], [0x12, 0x34]),
            ([0xf, 0xf, 0x0, 0x0], [0xff, 0x00]),
            ([0x9, 0xa, 0xb, 0xc, 0xd, 0xe], [0x9a, 0xbc, 0xde]),
            ([], []),
        ])
        def test_should_pack_nibbles_to_bytes(self, cairo_run, nibbles, expected_bytes):
            output = cairo_run("test__pack_nibbles", nibbles=nibbles)
            assert output == expected_bytes

        def test_should_panic_odd_number_of_nibbles(self, cairo_run):
            with cairo_error(message="nibbles_len must be even"):
                cairo_run("test__pack_nibbles", nibbles=[0x1, 0x2, 0x3])

    class TestLeafEncoding:
        @pytest.mark.parametrize("nibbles, is_leaf, expected_encoded", [
            ([0x0A, 0x0B, 0x0C], True, [0x3A, 0xBC]),  # Leaf, odd length
            ([0x0A, 0x0B, 0x0C], False, [0x1A, 0xBC]),  # Extension, odd length
            ([0x0A, 0x0B, 0x0C, 0x0D], True, [0x20, 0xAB, 0xCD]),  # Leaf, even length
            ([0x0A, 0x0B, 0x0C, 0x0D], False, [0x00, 0xAB, 0xCD]),  # Extension, even length
        ])
        def test_should_encode_path_leaf(self, cairo_run, nibbles, is_leaf, expected_encoded):
            output = cairo_run("test__encode_path_leaf", nibbles=nibbles, is_leaf=is_leaf)
            assert output == expected_encoded
