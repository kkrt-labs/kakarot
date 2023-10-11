import json
import logging
import os
from pathlib import Path

# Root of the GeneralStateTest in BlockchainTest format
EF_GENERAL_STATE_TEST_ROOT_PATH = Path(
    "./tests/integration/ef_tests/test_data/BlockchainTests/GeneralStateTests/"
)

DEFAULT_NETWORK = "Shanghai"

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def pytest_generate_tests(metafunc):
    """
    Parametrizes `ef_blockchain_test` fixture with cases loaded from the
    Ethereum Foundation tests repository, see:
    https://github.com/kkrt-labs/kakarot/blob/main/.gitmodules#L7.
    """
    if "ef_blockchain_test" not in metafunc.fixturenames:
        return

    if not EF_GENERAL_STATE_TEST_ROOT_PATH.exists():
        logger.warning(
            "EFTests directory %s doesn't exist. Run `make pull-ef-tests`",
            str(EF_GENERAL_STATE_TEST_ROOT_PATH),
        )
        metafunc.parametrize("ef_blockchain_test", [])
        return

    test_ids, test_cases = zip(
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
        test_cases,
        ids=test_ids,
    )
