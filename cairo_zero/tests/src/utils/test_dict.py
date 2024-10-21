import pytest


@pytest.mark.parametrize(
    "test_case",
    [
        "test__dict_keys__should_return_keys",
        "test__dict_values__should_return_values",
        "test__default_dict_copy__should_return_copied_dict",
    ],
)
def test_dict(cairo_run, test_case):
    cairo_run(test_case)
