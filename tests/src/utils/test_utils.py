import subprocess
from pathlib import Path

import pytest
from starkware.cairo.lang.vm.cairo_run import load_program
from starkware.cairo.lang.vm.cairo_runner import CairoRunner
from starkware.cairo.lang.vm.memory_dict import MemoryDict


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
    program = load_program(open(compiled_contract))
    runner = CairoRunner(
        program=program,
        layout="small",
        memory=MemoryDict(),
        proof_mode=False,
        allow_missing_builtins=False,
    )
    runner.initialize_segments()
    end = runner.initialize_main_entrypoint()
    runner.initialize_vm(hint_locals={"program_input": {}})
    runner.run_until_pc(end)
    runner.original_steps = runner.vm.current_step
    runner.end_run(disable_trace_padding=False)
    runner.print_output()
