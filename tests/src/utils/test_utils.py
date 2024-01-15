import pytest


class TestUtils:
    @pytest.mark.parametrize(
        "test_case,data,expected",
        [
            (
                "test__bytes4_array_to_bytes",
                [
                    0x68656C6C,
                    0x6F20776F,
                    0x726C6400,
                ],
                [
                    0x68,
                    0x65,
                    0x6C,
                    0x6C,
                    0x6F,
                    0x20,
                    0x77,
                    0x6F,
                    0x72,
                    0x6C,
                    0x64,
                    0x00,
                ],
            ),
            (
                "test__bytes_to_bytes4_array",
                [
                    0x68,
                    0x65,
                    0x6C,
                    0x6C,
                    0x6F,
                    0x20,
                    0x77,
                    0x6F,
                    0x72,
                    0x6C,
                    0x64,
                    0x00,
                ],
                [
                    0x68656C6C,
                    0x6F20776F,
                    0x726C6400,
                ],
            ),
        ],
    )
    def test_utils(self, cairo_run, test_case, data, expected):
        cairo_run(test_case, data=data, expected=expected)

    def test__bytes_i_to_uint256(self, cairo_run):
        cairo_run("test__bytes_i_to_uint256")
