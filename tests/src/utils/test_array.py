import pytest


class TestArray:
    class TestReverse:
        @pytest.mark.parametrize(
            "arr",
            [
                [0, 1, 2, 3, 4],
                [0, 1, 2, 3],
                [0, 1, 2],
                [0, 1],
                [0],
                [],
            ],
        )
        def test_should_return_reversed_array(self, cairo_run, arr):
            output = cairo_run("test__reverse", arr=arr)
            assert arr[::-1] == output

    class TestCountNotZero:
        @pytest.mark.parametrize(
            "arr",
            [
                [0, 1, 0, 0, 4],
                [0, 1, 0, 3],
                [0, 1, 0],
                [0, 1],
                [0],
                [],
            ],
        )
        def test_should_return_count_of_non_zero_elements(self, cairo_run, arr):
            output = cairo_run("test__count_not_zero", arr=arr)
            assert len(arr) - arr.count(0) == output[0]

    class TestSlice:
        @pytest.mark.parametrize("offset", [0, 1, 2, 3, 4, 5, 6])
        @pytest.mark.parametrize("size", [0, 1, 2, 3, 4, 5, 6])
        def test_should_return_slice(self, cairo_run, offset, size):
            arr = [0, 1, 2, 3, 4]
            output = cairo_run("test__slice", arr=arr, offset=offset, size=size)
            assert (arr + (offset + size) * [0])[offset : offset + size] == output

    class TestContains:
        @pytest.mark.parametrize(
            "arr, value, expected",
            [
                ([0, 1, 2, 3, 4], 1, True),
                ([0, 1, 2, 3], 5, False),
                ([0, 1, 19], 19, True),
                ([0], 0, True),
                ([], 1, False),
            ],
        )
        async def test_should_return_if_contains(self, cairo_run, arr, value, expected):
            output = cairo_run("test_contains", arr=arr, value=value)
            assert expected == output[0]
