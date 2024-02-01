import json
import logging
from contextlib import contextmanager
from functools import wraps
from pathlib import Path
from time import perf_counter
from typing import Any, Callable, Iterable, List, TypeVar, Union, cast

import pandas as pd
from starkware.cairo.lang.compiler.identifier_definition import LabelDefinition
from starkware.cairo.lang.tracer.profile import ProfileBuilder
from starkware.cairo.lang.tracer.tracer_data import TracerData
from starkware.starknet.testing.objects import StarknetCallInfo
from starkware.starknet.testing.starknet import StarknetContract

from tests.utils.coverage import CoverageFile

logging.basicConfig(format="%(levelname)-8s %(message)s")
logger = logging.getLogger("timer")

_time_report: List[dict] = []
_resources_report: List[dict] = []
# A mapping to fix the mismatch between the debug_info and the identifiers.
_label_scope = {
    "kakarot.constants.opcodes_label": "kakarot.constants",
    "kakarot.accounts.contract.library.internal.pow_": "kakarot.accounts.contract.library.internal",
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


class traceit:
    """
    Record resources used by a StarknetContract and VM.
    """

    _context = ""

    @classmethod
    @property
    def prefix(cls) -> str:
        """
        Prefix the log output with the context if used.
        """
        return cls._context + ":" if cls._context != "" else ""

    @classmethod
    def record_tx(
        cls,
        res: StarknetCallInfo,
        contract_name: str,
        attr_name: str,
        args: Iterable,
        kwargs: dict,
    ):
        resources = cast(
            dict,
            res.call_info.execution_resources.Schema().dump(
                res.call_info.execution_resources
            ),
        )
        resources = {
            **resources.pop("builtin_instance_counter"),
            **resources,
        }

        args_serializable = [_a.hex() if isinstance(_a, bytes) else _a for _a in args]
        kwargs_serializable = {
            k: v.hex() if isinstance(v, bytes) else v for k, v in kwargs.items()
        }
        _resources_report.append(
            {
                **({"context": cls._context} if cls._context != "" else {}),
                "contract_name": contract_name,
                "function_name": attr_name,
                "args": args_serializable,
                "kwargs": kwargs_serializable,
                **resources,
            }
        )
        logger.info(
            f"{cls.prefix}{contract_name}.{attr_name}({json.dumps(args_serializable)}, {json.dumps(kwargs_serializable)}) used {resources}"
        )

    @classmethod
    def pop_record(cls) -> dict:
        return _resources_report.pop()

    @classmethod
    def _trace_call(
        cls,
        invoke_fun: Callable,
        contract_name: str,
        attr_name: str,
        *args,
        **kwargs,
    ) -> Callable:
        """
        StarknetContract instances have methods defined in their corresponding cairo file.
        These methods, once called, return a StarknetContractFunctionInvocation instance.
        This class defines "call" and "execute" methods for view or external call to the underlying functions.
        The invoke_fun here is either one or the other.
        This wrapper will record the ExecutionResource of the corresponding call.
        """

        async def traced_fun(*a, **kw):
            res = await invoke_fun(*a, **kw)
            cls.record_tx(res, contract_name, attr_name, args, kwargs)
            return res

        return traced_fun

    @classmethod
    def _trace_attr(cls, fun: Callable, contract_name: str):
        """
        Apply this wrapper to a contract's method to keep track of the ExecutionResources used.
        """

        def wrapped(*args, **kwargs):
            prepared_call = fun(*args, **kwargs)
            for invoke_fun_name in ["execute", "call"]:
                if hasattr(prepared_call, invoke_fun_name):
                    setattr(
                        prepared_call,
                        invoke_fun_name,
                        cls._trace_call(
                            getattr(prepared_call, invoke_fun_name),
                            contract_name,
                            fun.__name__,
                            *args,
                            **kwargs,
                        ),
                    )
                    prepared_call._traced = True
            return prepared_call

        return wrapped

    @staticmethod
    def trace(contract: StarknetContract, name: str) -> StarknetContract:
        for attr_name in contract._abi_function_mapping.keys():
            setattr(
                contract,
                attr_name,
                traceit._trace_attr(
                    getattr(contract, attr_name),
                    contract_name=name,
                ),
            )
        return contract

    @staticmethod
    def trace_all(deploy: Callable) -> Callable:
        async def traced_deploy(*args, **kwargs):
            contract = await deploy(*args, **kwargs)
            if args:
                source = args[0]
            else:
                source = kwargs["class_hash"]
            traceit.trace(contract, hex(source))
            return contract

        return traced_deploy

    @classmethod
    @contextmanager
    def context(
        cls,
        context,
    ):
        """
        Context manager to add a context field to the logs and records.
        """
        prev_context = cls._context
        cls._context = context
        yield
        cls._context = prev_context

    @classmethod
    def trace_run(cls, run):
        def _run(*args, **kwargs):
            run(*args, **kwargs)

            if cls._context:
                logger.info(f"Dumping TracerData for runner {cls._context}")
                runner = kwargs.get("runner", args[0])
                runner.relocate()
                tracer_data = TracerData(
                    program=runner.program,
                    memory=runner.relocated_memory,
                    trace=runner.relocated_trace,
                    program_base=1,
                    debug_info=runner.get_relocated_debug_info(),
                )
                profile = profile_from_tracer_data(tracer_data)
                with open(f"{cls._context}.pb.gz", "wb") as fp:
                    fp.write(profile)

            return

        return _run


def reports():
    return (
        (
            pd.DataFrame(_time_report)
            .assign(
                contract=lambda df: df.kwargs.map(
                    lambda kw: kw.get("source") or hex(kw.get("class_hash"))
                )
            )
            .reindex(columns=["contract", "name", "duration", "args", "kwargs"])
        ),
        pd.DataFrame(_resources_report)
        if not _resources_report
        else (
            pd.DataFrame(_resources_report)
            .assign(context=lambda df: df.get("context", ""))
            .fillna({"context": ""})
            .fillna(0)
            .pipe(
                lambda df: df.reindex(
                    columns=[
                        "context",
                        "contract_name",
                        "function_name",
                        *df.drop(
                            [
                                "context",
                                "contract_name",
                                "function_name",
                                "args",
                                "kwargs",
                            ],
                            axis=1,
                            errors="ignore",
                        ).columns,
                        "args",
                        "kwargs",
                    ]
                )
            )
            .sort_values(["n_steps"], ascending=False)
        ),
    )


def dump_reports(path: Union[str, Path]):
    p = Path(path)
    p.mkdir(exist_ok=True, parents=True)
    times, traces = reports()
    times.to_csv(p / "times.csv", index=False)
    traces.to_csv(p / "resources.csv", index=False)


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
