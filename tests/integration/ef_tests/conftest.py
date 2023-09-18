from utils import filter_by_case_ids, load_default_ef_tests, load_ef_tests


def pytest_addoption(parser):
    parser.addoption(
        "--target",
        action="store",
        type=str,
        help="Specify ef test directory or suite to run, where a suite is a json file.",
    )
    parser.addoption(
        "--case",
        action="append",
        type=str,
        nargs="+",
        help="Specify one or more particular cases within the JSON suite files to run",
    )
    parser.addoption(
        "--network",
        action="store",
        type=str,
        default="Shanghai",
        help="Specify the network to use, defaults to Shanghai",
    )


def pytest_generate_tests(metafunc):
    if "ef_test" in metafunc.fixturenames:
        suite_or_directory = metafunc.config.getoption("target")
        case_ids = metafunc.config.getoption("case")
        network_name = metafunc.config.getoption("network")

        if suite_or_directory:
            ef_tests = load_ef_tests(suite_or_directory, network_name)
            if not ef_tests:
                raise ValueError(
                    f"No tests found for `--target` param {suite_or_directory}"
                )
        else:
            ef_tests = load_default_ef_tests()

        if case_ids:
            # Filter ef_tests based on the provided case names
            # Flattening the list because `--case` with `action="append"` and `nargs="+"`
            # results in a nested list, even if only one value is provided.
            flattened_case_ids = [item for sublist in case_ids for item in sublist]
            ef_tests = filter_by_case_ids(ef_tests, flattened_case_ids)

        ef_test_ids, ef_test_objects = zip(*ef_tests)

        metafunc.parametrize("ef_test", ef_test_objects, ids=ef_test_ids)
