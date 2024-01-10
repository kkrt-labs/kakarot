import subprocess
from pathlib import Path

import pytest

from tests.utils.cairo import run_program_entrypoint


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


@pytest.mark.parametrize(
    "test_case,data,expected",
    [
        (
            "test__bytes4_array_to_bytes",
            [
                0x68656C6C,
                0x6F20776F,
                0x726C6400,
            ],
            [
                0x68,
                0x65,
                0x6C,
                0x6C,
                0x6F,
                0x20,
                0x77,
                0x6F,
                0x72,
                0x6C,
                0x64,
                0x00,
            ],
        ),
        (
            "test__bytes_to_bytes4_array",
            [
                0x68,
                0x65,
                0x6C,
                0x6C,
                0x6F,
                0x20,
                0x77,
                0x6F,
                0x72,
                0x6C,
                0x64,
                0x00,
            ],
            [
                0x68656C6C,
                0x6F20776F,
                0x726C6400,
            ],
        ),
        ("test__bytes_i_to_uint256", [], []),
    ],
)
def test_utils(compiled_contract, test_case, data, expected):
    run_program_entrypoint(
        compiled_contract,
        test_case,
        {"data": data, "expected": expected},
    )
