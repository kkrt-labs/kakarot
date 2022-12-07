import pytest

from .execute import test_cases as test_cases_execute

params_execute = [
    pytest.param(case.pop("params"), **case) for case in test_cases_execute
]
