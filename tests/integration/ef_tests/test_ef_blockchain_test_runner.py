import pytest
from runner import create_test_function

from utils import load_ef_blockchain_tests

# In order to use the standard `keyword` and `markexpr` ux for pytest
# we generate a test for each case.

all_ef_blockchain_test_cases = load_ef_blockchain_tests(".", "Shanghai")

for ef_case_name, ef_test in all_ef_blockchain_test_cases:
    test_func = create_test_function(ef_test)
    test_func.__name__ = f"test_{ef_case_name}"

    globals()[f"test_{ef_case_name}"] = test_func
