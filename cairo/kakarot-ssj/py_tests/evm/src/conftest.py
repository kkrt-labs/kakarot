import json
import re
import subprocess
from typing import Any, Callable, Tuple, Type, Union

import pytest
from py_tests.test_utils.deserializer import Deserializer
from py_tests.test_utils.serializer import Serializer
from py_tests.test_utils.types import ByteArray


@pytest.fixture
def cairo_run() -> Callable[[str, Union[Type[Any], Tuple[Type[Any], ...]], ...], Any]:
    def _cairo_run(
        function_name: str,
        output_type: Union[Type[Any], Tuple[Type[Any], ...]],
        *args: Any,
    ) -> Any:
        # Serialize arguments into a compatible format for scarb cairo-run
        # JSON encode the serialized arguments - [1,2,3] -> "[1,2,3]"
        serialized_args = json.dumps(Serializer.serialize_args(args))

        command = [
            "scarb",
            "pytest",
            "-p",
            "evm",
            "--function",
            function_name,
            serialized_args,
            "--no-build",
        ]

        try:
            result = subprocess.run(
                command,
                cwd="cairo/kakarot-ssj",
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Command failed with error: {e.stderr}") from e

        stdout = result.stdout.strip()
        # Extract panic message if present
        panic_match = re.search(r"Run panicked with \[\d+ \(\'(.*?)\'\)", stdout)
        if panic_match:
            raise ValueError(f"Run panicked with: {panic_match.group(1)}")

        match = re.search(
            r"Run completed successfully, returning (\[.*?\])", result.stdout
        )
        if not match:
            raise ValueError("No array found in the output")

        output = ByteArray(json.loads(match.group(1)))
        return Deserializer.deserialize(output, output_type)

    return _cairo_run
