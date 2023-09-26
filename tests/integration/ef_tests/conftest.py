import json
import os
from pathlib import Path

# Root of the GeneralStateTest in BlockchainTest format
EF_GENERAL_STATE_TEST_ROOT_PATH = Path(
    "./tests/integration/ef_tests/test_data/BlockchainTests/GeneralStateTests/"
)

DEFAULT_NETWORK = "Shanghai"


def pytest_generate_tests(metafunc):
    """
     Enable devs to use the familiar keyword (-k argument) to select the GeneralStateTransition tests in BlockchainTest format of the EF test suite,
    which are loaded as fixtures.
    """
    if "ef_blockchain_test" in metafunc.fixturenames:
        test_ids, test_objects = zip(
            *[
                (name, content)
                for (root, _, files) in os.walk(EF_GENERAL_STATE_TEST_ROOT_PATH)
                for file in files
                if file.endswith(".json")
                for name, content in json.loads((Path(root) / file).read_text()).items()
                if content["network"] == DEFAULT_NETWORK
            ]
        )

        metafunc.parametrize(
            "ef_blockchain_test",
            test_objects,
            ids=test_ids,
        )
