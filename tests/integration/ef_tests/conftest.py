import pytest


def pytest_runtest_setup(item):
    keywordexpr = item.config.getoption("keyword")

    # If the keyword expression doesn't match the nodeid (test name), skip the test
    if item.nodeid.find(keywordexpr) == -1 or not keywordexpr :
        pytest.skip("Skipping test, didn't match keyword expression.")
