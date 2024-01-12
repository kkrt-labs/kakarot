import pytest


@pytest.fixture(scope="module")
def program(cairo_compile):
    return cairo_compile("tests/src/utils/test_dict.cairo")


@pytest.mark.parametrize(
    "test_case",
    [
        "test__dict_keys__should_return_keys",
        "test__dict_values__should_return_values",
        "test__default_dict_copy__should_return_copied_dict",
    ],
)
def test_dict(cairo_run, program, test_case):
    cairo_run(program, test_case)
