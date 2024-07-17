import io
import json
import logging
import os
import shutil
import tarfile
from pathlib import Path

import requests

EF_TESTS_TAG = "v13.3-kkrt-1"
EF_TESTS_URL = (
    f"https://github.com/kkrt-labs/tests/archive/refs/tags/{EF_TESTS_TAG}.tar.gz"
)
EF_TESTS_DIR = Path("tests") / "ef_tests" / "test_data" / EF_TESTS_TAG
EF_TESTS_PARSED_DIR = Path("tests") / "ef_tests" / "test_data" / "parsed"

DEFAULT_NETWORK = "Cancun"

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def generate_tests():
    if not EF_TESTS_DIR.exists():
        response = requests.get(EF_TESTS_URL)
        with tarfile.open(fileobj=io.BytesIO(response.content), mode="r:gz") as tar:
            tar.extractall(EF_TESTS_DIR)

    test_cases = {
        f"{os.path.basename(root)}_{name}": content
        for (root, _, files) in os.walk(EF_TESTS_DIR)
        for file in files
        if file.endswith(".json")
        and "BlockchainTests/GeneralStateTests" in root
        and "Pyspecs" not in root
        for name, content in json.loads((Path(root) / file).read_text()).items()
        if content.get("network") == DEFAULT_NETWORK
    }

    # Add tests from BlockchainTests/GeneralStateTests/Pyspecs
    test_cases.update(
        {
            f"{name.split('::')[-1]}": content
            for (root, _, files) in os.walk(EF_TESTS_DIR)
            for file in files
            if file.endswith(".json")
            and "BlockchainTests/GeneralStateTests/Pyspecs" in root
            for name, content in json.loads((Path(root) / file).read_text()).items()
            if f"fork_{DEFAULT_NETWORK}" in name
        }
    )

    shutil.rmtree(EF_TESTS_PARSED_DIR, ignore_errors=True)
    EF_TESTS_PARSED_DIR.mkdir(parents=True, exist_ok=True)

    for test_name, test_case in test_cases.items():
        try:
            json.dump(
                test_case,
                open(EF_TESTS_PARSED_DIR / f"{test_name}.json", "w"),
                indent=4,
            )
        except Exception as e:
            print(e)


if __name__ == "__main__":
    generate_tests()
