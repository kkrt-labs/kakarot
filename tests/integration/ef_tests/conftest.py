import time

from utils import load_ef_blockchain_tests


# This enables devs to use the familiar keyword (-k argument) to select a subset of the EF test suite,
# which are loaded as fixtures.
def pytest_generate_tests(metafunc):
    if "ef_blockchain_test" in metafunc.fixturenames:
        keyword = metafunc.config.getoption("keyword")

        if not keyword:
            # with no keyword, we parametrize as empty
            metafunc.parametrize(
                "ef_blockchain_test",
                [],
                ids=[],
            )
        else:
            start_time = time.time()
            ef_blockchain_tests = load_ef_blockchain_tests(keyword)
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
