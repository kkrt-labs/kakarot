import logging

from utils import (
    filter_by_case_ids,
    load_default_ef_blockchain_tests,
    load_ef_blockchain_tests,
)

logger = logging.getLogger()


def pytest_addoption(parser):
    parser.addoption(
        "--target",
        action="store",
        type=str,
        help="Specify ef test directory or suite to run, where a suite is a json file.",
        default=None,
    )
    parser.addoption(
        "--case",
        action="append",
        type=str,
        nargs="+",
        help="Specify one or more particular cases within the JSON suite files to run",
        default=None,
    )
    parser.addoption(
        "--network",
        action="store",
        type=str,
        default="Shanghai",
        help="Specify the network to use, defaults to Shanghai",
    )


def pytest_generate_tests(metafunc):
    if "ef_blockchain_test" in metafunc.fixturenames:
        suite_or_directory = metafunc.config.getoption("target")
        case_ids = metafunc.config.getoption("case")
        network_name = metafunc.config.getoption("network")

        if suite_or_directory:
            ef_blockchain_tests = load_ef_blockchain_tests(
                suite_or_directory, network_name
            )
        else:
            ef_blockchain_tests = load_default_ef_blockchain_tests(network_name)

        if case_ids:
            # Filter ef_tests based on the provided case names
            # Flattening the list because `--case` with `action="append"` and `nargs="+"`
            # results in a nested list, even if only one value is provided.
            flattened_case_ids = [item for sublist in case_ids for item in sublist]
            ef_blockchain_tests = filter_by_case_ids(
                ef_blockchain_tests, flattened_case_ids
            )

        if not ef_blockchain_tests:
            logger.warning(
                f"No tests found for `--target` param {suite_or_directory} and `--case_ids` {case_ids}. Skipping tests."
            )
        else:
            ef_blockchain_test_ids, ef_blockchain_test_objects = zip(
                *ef_blockchain_tests
            )
            metafunc.parametrize(
                "ef_blockchain_test",
                ef_blockchain_test_objects,
                ids=ef_blockchain_test_ids,
            )
