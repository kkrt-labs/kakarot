import pytest


@pytest.fixture(scope="module")
def program(cairo_compile):
    return cairo_compile("tests/src/utils/test_array.cairo")


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
        def test_should_return_reversed_array(self, cairo_run, program, arr):
            output = cairo_run(
                program=program,
                entrypoint="test__reverse",
                program_input={"arr": arr},
            )
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
        def test_should_return_count_of_non_zero_elements(
            self, cairo_run, program, arr
        ):
            output = cairo_run(
                program=program,
                entrypoint="test__count_not_zero",
                program_input={"arr": arr},
            )
            assert len(arr) - arr.count(0) == output[0]

    class TestSlice:
        @pytest.mark.parametrize(
            "offset",
            [0, 1, 2, 3, 4, 5, 6],
        )
        @pytest.mark.parametrize(
            "size",
            [0, 1, 2, 3, 4, 5, 6],
        )
        def test_should_return_slice(self, cairo_run, program, offset, size):
            arr = [0, 1, 2, 3, 4]
            output = cairo_run(
                program=program,
                entrypoint="test__slice",
                program_input={"arr": arr, "offset": offset, "size": size},
            )
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
        async def test_should_return_if_contains(self, cairo_run, program, arr, value, expected):
            output = cairo_run(
                program=program,
                entrypoint="test_contains",
                program_input={"arr": arr, "value": value},
            )
            assert expected == output[0]
