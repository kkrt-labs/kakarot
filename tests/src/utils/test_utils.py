import subprocess
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def compiled_contract():
    path = Path("tests/src/utils/test_utils.cairo")
    compiled_path = path.parent / f"{path.stem}_compiled.json"
    subprocess.run(
        f"cairo-compile --output {compiled_path} {path}",
        env={"CAIRO_PATH": "src"},
        shell=True,
    )

    yield compiled_path

    compiled_path.unlink()


def test_utils(compiled_contract):
    process = subprocess.run(
        f"cairo-run --program {compiled_contract} --layout=small",
        shell=True,
        capture_output=True,
    )
    if process.returncode:
        raise ValueError(process.stderr.decode("utf-8"))
    print(process.stdout.decode("utf-8"))
