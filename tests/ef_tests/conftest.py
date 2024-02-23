import logging
import os

from scripts.ef_tests.fetch import EF_TESTS_PARSED_DIR

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def pytest_generate_tests(metafunc):
    """
    Parametrizes `ef_blockchain_test` fixture.

    Only the file name is returned to avoid loading the entire cases into memory.
    """
    if "ef_blockchain_test" not in metafunc.fixturenames:
        return

    try:
        test_cases = os.listdir(EF_TESTS_PARSED_DIR)
    except FileNotFoundError:
        test_cases = []

    metafunc.parametrize("ef_blockchain_test", test_cases)
