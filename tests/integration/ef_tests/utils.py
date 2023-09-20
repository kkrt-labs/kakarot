import json
import os

from tests.utils.uint256 import uint256_to_int

# Root of the GeneralStateTest in BlockchainTest format
EF_GENERAL_STATE_TEST_ROOT_PATH = (
    "./tests/integration/ef_tests/testdata/BlockchainTests/GeneralStateTests/"
)


def display_storage(uint256_tuple):
    return hex(uint256_to_int(*uint256_tuple))


def is_account_eoa(state: dict) -> bool:
    return state.get("code") in [None, "0x"] and not state.get("storage")


def load_json_file(filepath):
    with open(filepath, "r") as f:
        return json.load(f)


def filter_by_case_ids(ef_cases, case_ids):
    return [
        (case_id, case_obj) for case_id, case_obj in ef_cases if case_id in case_ids
    ]


def filter_network_tests(json_content, network):
    return [
        (test_name, test_content)
        for test_name, test_content in json_content.items()
        if test_content["network"] == network
    ]


def load_ef_blockchain_tests_from_directory(directory_path, network):
    ef_tests = []
    for filename in os.listdir(directory_path):
        filepath = os.path.join(directory_path, filename)

        # Check if filepath is a directory
        if os.path.isdir(filepath):
            ef_tests.extend(load_ef_blockchain_tests_from_directory(filepath, network))
        elif filename.endswith(".json"):
            json_content = load_json_file(filepath)
            ef_tests.extend(filter_network_tests(json_content, network))

    return ef_tests


def load_ef_blockchain_tests(relative_path, network):
    """
    Load Ethereum Foundation tests from the directory or file specified
    under a fixed root path.
    """
    full_path = os.path.join(EF_GENERAL_STATE_TEST_ROOT_PATH, relative_path)

    if not os.path.exists(full_path):
        raise ValueError(f"The path {full_path} does not exist.")

    if full_path.endswith(".json"):
        if not os.path.isfile(full_path):
            raise ValueError(f"The file {full_path} does not exist.")
        json_content = load_json_file(full_path)
        return filter_network_tests(json_content, network)

    elif os.path.isdir(full_path):
        return load_ef_blockchain_tests_from_directory(full_path, network)

    else:
        raise ValueError(
            f"Invalid full_path: {full_path}. It's neither a directory nor a .json file."
        )


def load_default_ef_blockchain_tests(network_name):
    return {}
