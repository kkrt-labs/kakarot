import json
import logging
from functools import wraps
from pathlib import Path
from time import perf_counter
from typing import Any, Callable, List, TypeVar, Union, cast

from starkware.cairo.lang.compiler.identifier_definition import LabelDefinition
from starkware.cairo.lang.tracer.profile import ProfileBuilder

from tests.utils.coverage import CoverageFile

logging.basicConfig(format="%(levelname)-8s %(message)s")
logger = logging.getLogger("timer")

_time_report: List[dict] = []
# A mapping to fix the mismatch between the debug_info and the identifiers.
_label_scope = {
    "kakarot.constants.opcodes_label": "kakarot.constants",
    "kakarot.accounts.library.internal.pow_": "kakarot.accounts.library.internal",
}
T = TypeVar("T", bound=Callable[..., Any])


def timeit(fun: T) -> T:
    @wraps(fun)
    async def timed_fun(*args, **kwargs):
        start = perf_counter()
        res = await fun(*args, **kwargs)
        stop = perf_counter()
        duration = stop - start
        _time_report.append(
            {"name": fun.__name__, "args": args, "kwargs": kwargs, "duration": duration}
        )
        logger.info(
            f"{fun.__name__}({json.dumps(args)}, {json.dumps(kwargs)}) in {duration:.2f}s"
        )
        return res

    return cast(T, timed_fun)


def dump_coverage(path: Union[str, Path], files: List[CoverageFile]):
    p = Path(path)
    p.mkdir(exist_ok=True, parents=True)
    json.dump(
        {
            "coverage": {
                file.name.split("__main__/")[-1]: {
                    **{line: 0 for line in file.missed},
                    **{line: 1 for line in file.covered},
                }
                for file in files
            }
        },
        open(p / "coverage.json", "w"),
        indent=2,
    )


def profile_from_tracer_data(tracer_data):
    """
    Un-bundle the profile.profile_from_tracer_data to hard fix the opcode_labels name mismatch
    between the debug_info and the identifiers; and adding a try/catch for the traces (pc going out of bounds).
    """

    builder = ProfileBuilder(
        initial_fp=tracer_data.trace[0].fp, memory=tracer_data.memory
    )

    # Functions.
    for name, ident in tracer_data.program.identifiers.as_dict().items():
        if not isinstance(ident, LabelDefinition):
            continue
        builder.function_id(
            name=_label_scope.get(str(name), str(name)),
            inst_location=tracer_data.program.debug_info.instruction_locations[
                ident.pc
            ],
        )

    # Locations.
    for (
        pc_offset,
        inst_location,
    ) in tracer_data.program.debug_info.instruction_locations.items():
        builder.location_id(
            pc=tracer_data.get_pc_from_offset(pc_offset),
            inst_location=inst_location,
        )

    # Samples.
    for trace_entry in tracer_data.trace:
        try:
            builder.add_sample(trace_entry)
        except KeyError:
            pass

    return builder.dump()
