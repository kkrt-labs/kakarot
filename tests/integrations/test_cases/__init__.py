import pytest

from .erc20 import test_cases as test_cases_erc20
from .execute import test_cases as test_cases_execute
from .execute_at_address import test_cases as test_cases_execute_at_address

params_execute = [
    pytest.param(case.pop("params"), **case) for case in test_cases_execute
]

params_execute_at_address = [
    pytest.param(case.pop("params"), **case) for case in test_cases_execute_at_address
]

params_erc20 = [pytest.param(case.pop("params"), **case) for case in test_cases_erc20]
