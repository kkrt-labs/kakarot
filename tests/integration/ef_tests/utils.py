import json
import os

from _pytest.mark.expression import Expression

from tests.utils.uint256 import uint256_to_int

# Root of the GeneralStateTest in BlockchainTest format
EF_GENERAL_STATE_TEST_ROOT_PATH = (
    "./tests/integration/ef_tests/test_data/BlockchainTests/GeneralStateTests/"
)

DEFAULT_NETWORK = "Shanghai"


def display_storage(uint256_tuple):
    return hex(uint256_to_int(*uint256_tuple))


def is_account_eoa(state: dict) -> bool:
    return state.get("code") in [None, "0x"] and not state.get("storage")


def create_matcher(keyword):
    expr = Expression.compile(keyword)
    return lambda ident: expr.evaluate(lambda s: s in ident)


def filter_by_keyword(ef_cases, keyword):
    matcher = create_matcher(keyword)
    return [(case_id, case_obj) for case_id, case_obj in ef_cases if matcher(case_id)]


def process_json_file(filepath):
    with open(filepath, "r") as f:
        json_content = json.load(f)
    return [
        (test_name, test_content)
        for test_name, test_content in json_content.items()
        if test_content["network"] == DEFAULT_NETWORK
    ]


def load_ef_blockchain_tests_from_path(directory_path):
    ef_tests = []
    if os.path.isfile(directory_path):  # Handle case where path is a file
        ef_tests.extend(process_json_file(directory_path))
    else:  # Handle case where path is a directory
        for dirpath, _, filenames in os.walk(directory_path):
            for filename in filenames:
                if filename.endswith(".json"):
                    filepath = os.path.join(dirpath, filename)
                    ef_tests.extend(process_json_file(filepath))

    return ef_tests


def _load_ef_blockchain_tests(relative_path):
    """
    Load Ethereum Foundation tests from the directory or file specified
    under a fixed root path.
    """
    full_path = os.path.join(EF_GENERAL_STATE_TEST_ROOT_PATH, relative_path)
    if not os.path.exists(full_path):
        raise ValueError(f"The path {full_path} does not exist.")

    return load_ef_blockchain_tests_from_path(full_path)


def load_ef_blockchain_tests(keyword):
    # Load all available tests and filter them using the keyword
    all_tests = _load_ef_blockchain_tests(".")
    return filter_by_keyword(all_tests, keyword)
