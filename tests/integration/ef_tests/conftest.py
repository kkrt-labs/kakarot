import logging
import time

from utils import (
    is_directory_or_file_keyword,
    load_all_ef_blockchain_tests,
    load_ef_blockchain_tests,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# This enables devs to use the familiar keyword (-k argument) to select a subset of the EF test suite,
# which are loaded as fixtures.
def pytest_generate_tests(metafunc):
    if "ef_blockchain_test" in metafunc.fixturenames:
        keyword = metafunc.config.getoption("keyword")
        logger.info(f"EF test runner ran with {keyword=}")
        if not keyword:
            # with no keyword, we parametrize as empty
            metafunc.parametrize(
                "ef_blockchain_test",
                [],
                ids=[],
            )

        else:
            start_time = time.time()

            if is_directory_or_file_keyword(keyword):
                # allows user to not load all ef-tests to then filter
                # a user can either load all tests in a subdirectory or in a json file
                # following the directory structure here:
                # https://github.com/ethereum/tests/tree/develop/BlockchainTests/GeneralStateTests

                ef_blockchain_tests = load_ef_blockchain_tests(keyword)
                metafunc.config.option.keyword = ""  # Override keyword expression to avoid deselection when using a 'direct' keyword.
            else:
                ef_blockchain_tests = load_all_ef_blockchain_tests()
            # Calculate and print the elapsed time
            elapsed_time = time.time() - start_time
            print(f"Time taken to load_ef_blockchain_tests: {elapsed_time} seconds")

            ef_blockchain_test_ids, ef_blockchain_test_objects = (
                zip(*ef_blockchain_tests) if ef_blockchain_tests else ([], [])
            )

            # Parametrize regardless of whether ef_blockchain_tests is empty or not
            metafunc.parametrize(
                "ef_blockchain_test",
                ef_blockchain_test_objects,
                ids=ef_blockchain_test_ids,
            )
