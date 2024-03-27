import json
import logging
import os
import shutil
from pathlib import Path
from time import perf_counter
from typing import AsyncGenerator

import pandas as pd
import pytest
import pytest_asyncio
from starkware.cairo.lang.cairo_constants import DEFAULT_PRIME
from starkware.cairo.lang.compiler.cairo_compile import compile_cairo, get_module_reader
from starkware.cairo.lang.compiler.scoped_name import ScopedName
from starkware.cairo.lang.tracer.tracer_data import TracerData
from starkware.cairo.lang.vm import cairo_runner
from starkware.cairo.lang.vm.cairo_runner import CairoRunner
from starkware.cairo.lang.vm.memory_dict import MemoryDict
from starkware.cairo.lang.vm.memory_segments import FIRST_MEMORY_ADDR as PROGRAM_BASE
from starkware.starknet.business_logic.execution.execute_entry_point import (
    ExecuteEntryPoint,
)
from starkware.starknet.business_logic.state.state_api_objects import BlockInfo
from starkware.starknet.compiler.starknet_pass_manager import starknet_pass_manager
from starkware.starknet.definitions.general_config import StarknetGeneralConfig
from starkware.starknet.testing.starknet import Starknet

from tests.utils.constants import BLOCK_NUMBER, BLOCK_TIMESTAMP
from tests.utils.coverage import VmWithCoverage, report_runs
from tests.utils.hints import debug_info
from tests.utils.reporting import (
    dump_coverage,
    dump_reports,
    profile_from_tracer_data,
    timeit,
    traceit,
)
from tests.utils.serde import Serde
from tests.utils.syscall_handler import SyscallHandler

cairo_runner.VirtualMachine = VmWithCoverage

pd.set_option("display.max_rows", 500)
pd.set_option("display.max_columns", 500)
pd.set_option("display.width", 1000)

logging.getLogger("asyncio").setLevel(logging.ERROR)
logger = logging.getLogger()


@pytest_asyncio.fixture(scope="session")
async def starknet(worker_id, request) -> AsyncGenerator[Starknet, None]:
    config = StarknetGeneralConfig(
        invoke_tx_max_n_steps=2**24, validate_max_n_steps=2**24  # type: ignore
    )
    starknet = await Starknet.empty(config)
    starknet.state.state.update_block_info(
        BlockInfo.create_for_testing(
            block_number=BLOCK_NUMBER, block_timestamp=BLOCK_TIMESTAMP
        )
    )
    starknet.deploy = traceit.trace_all(timeit(starknet.deploy))
    starknet.deprecated_declare = timeit(starknet.deprecated_declare)
    if request.config.getoption("profile_cairo"):
        ExecuteEntryPoint._run = traceit.trace_run(ExecuteEntryPoint._run)
        logger.info("profile-cairo option enabled")
    else:
        logger.info("profile-cairo option disabled")
    output_dir = Path("coverage")
    shutil.rmtree(output_dir, ignore_errors=True)

    yield starknet

    output_dir.mkdir(exist_ok=True, parents=True)
    files = report_runs(excluded_file={"site-packages", "tests"})
    total_covered = []
    for file in files:
        if file.pct_covered < 80:
            logger.warning(f"{file.name} only {file.pct_covered:.2f}% covered")
        total_covered.append(file.pct_covered)
    if files and (val := not sum(total_covered) / len(files)) >= 80:
        logger.warning(f"Project is not covered enough {val:.2f})")

    if worker_id == "master":
        dump_reports(output_dir)
        dump_coverage(output_dir, files)
    else:
        dump_reports(output_dir / worker_id)
        dump_coverage(output_dir / worker_id, files)
        if len(os.listdir(output_dir)) == int(os.environ["PYTEST_XDIST_WORKER_COUNT"]):
            # This is the last teardown of the test suite, merge the files
            resources = pd.concat(
                [pd.read_csv(f) for f in output_dir.glob("**/resources.csv")],
            )
            if not resources.empty:
                resources.sort_values(["n_steps"], ascending=False).to_csv(
                    output_dir / "resources.csv", index=False
                )
            times = pd.concat(
                [pd.read_csv(f) for f in output_dir.glob("**/times.csv")],
                ignore_index=True,
            )
            if not times.empty:
                times.sort_values(["duration"], ascending=False).to_csv(
                    output_dir / "times.csv", index=False
                )


def cairo_compile(path):
    module_reader = get_module_reader(cairo_path=["src"])

    pass_manager = starknet_pass_manager(
        prime=DEFAULT_PRIME,
        read_module=module_reader.read,
        disable_hint_validation=True,
    )

    return compile_cairo(
        Path(path).read_text(),
        pass_manager=pass_manager,
        debug_info=True,
    )


@pytest.fixture(scope="module")
def cairo_run(request) -> list:
    """
    Run the cairo program corresponding to the python test file at a given entrypoint with given program inputs as kwargs.
    Returns the output of the cairo program put in the output memory segment.

    When --profile-cairo is passed, the cairo program is run with the tracer enabled and the resulting trace is dumped.

    Logic is mainly taken from starkware.cairo.lang.vm.cairo_run with minor updates like the addition of the output segment.
    """
    cairo_file = Path(request.node.fspath).with_suffix(".cairo")
    if not cairo_file.exists():
        raise ValueError(f"Missing cairo file: {cairo_file}")

    start = perf_counter()
    program = cairo_compile(cairo_file)
    stop = perf_counter()
    logger.info(f"{cairo_file} compiled in {stop - start:.2f}s")

    def _factory(entrypoint, **kwargs) -> list:
        implicit_args = program.identifiers.get_by_full_name(
            ScopedName(path=["__main__", entrypoint, "ImplicitArgs"])
        ).members.keys()
        # Fix builtins runner based on the implicit args since the compiler doesn't find them
        program.builtins = [
            builtin
            # This list is extracted from the builtin runners
            # Builtins have to be declared in this order
            for builtin in [
                "output",
                "pedersen",
                "range_check",
                "ecdsa",
                "bitwise",
                "ec_op",
                "keccak",
                "poseidon",
            ]
            if builtin in {arg.replace("_ptr", "") for arg in implicit_args}
        ]

        memory = MemoryDict()
        runner = CairoRunner(
            program=program,
            layout="starknet_with_keccak",
            memory=memory,
            proof_mode=False,
            allow_missing_builtins=False,
        )
        runner.initialize_segments()

        stack = []
        for arg in implicit_args:
            builtin_runner = runner.builtin_runners.get(arg.replace("_ptr", "_builtin"))
            if builtin_runner is not None:
                stack.extend(builtin_runner.initial_stack())
                continue
            if arg == "syscall_ptr":
                syscall = runner.segments.add()
                stack.append(syscall)
                continue

        add_output = (
            "output_ptr"
            in program.identifiers.get_by_full_name(
                ScopedName(path=["__main__", entrypoint, "Args"])
            ).members.keys()
        )
        if add_output:
            output_ptr = runner.segments.add()
            stack.append(output_ptr)

        return_fp = runner.segments.add()
        end = runner.segments.add()
        stack += [return_fp, end]

        runner.initialize_state(
            entrypoint=program.identifiers.get_by_full_name(
                ScopedName(path=["__main__", entrypoint])
            ).pc,
            stack=stack,
        )
        runner.initial_fp = runner.initial_ap = runner.execution_base + len(stack)
        runner.final_pc = end

        runner.initialize_vm(
            hint_locals={
                "program_input": kwargs,
                "syscall_handler": SyscallHandler(),
            },
            static_locals={"debug_info": debug_info(program)},
        )
        runner.run_until_pc(stack[-1])
        runner.original_steps = runner.vm.current_step
        runner.end_run(disable_trace_padding=False)
        runner.relocate()

        if request.config.getoption("profile_cairo"):
            tracer_data = TracerData(
                program=program,
                memory=runner.relocated_memory,
                trace=runner.relocated_trace,
                debug_info=runner.get_relocated_debug_info(),
                program_base=PROGRAM_BASE,
            )
            data = profile_from_tracer_data(tracer_data)

            output_path = (
                str(
                    request.node.path.parent
                    / f"{request.node.path.stem}.{entrypoint}_{(json.dumps(kwargs) if kwargs else '')}"
                )[:180]
                + ".pb.gz"
            )
            with open(output_path, "wb") as fp:
                fp.write(data)

        serde = Serde(runner)
        returned_data = program.identifiers.get_by_full_name(
            ScopedName(path=["__main__", entrypoint, "Return"])
        )
        final_output = None
        if add_output:
            final_output = serde.serialize_list(output_ptr)
        function_output = serde.serialize(returned_data.cairo_type)
        if final_output is not None:
            function_output = (
                function_output
                if isinstance(function_output, list)
                else [function_output]
            )
            if len(function_output) > 0:
                final_output = (final_output, *function_output)
        else:
            final_output = function_output

        return final_output

    return _factory
