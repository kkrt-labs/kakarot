import json
import logging
import os
from contextlib import contextmanager
from functools import wraps
from pathlib import Path
from time import perf_counter
from typing import Any, Callable, Iterable, List, TypeVar, Union, cast

import pandas as pd
from cairo_coverage.cairo_coverage import CoverageFile
from starkware.cairo.lang.tracer.profile import profile_from_tracer_data
from starkware.cairo.lang.tracer.tracer_data import TracerData
from starkware.starknet.testing.objects import StarknetCallInfo
from starkware.starknet.testing.starknet import StarknetContract

logging.basicConfig(format="%(levelname)-8s %(message)s")
logger = logging.getLogger("timer")

_time_report: List[dict] = []
_resources_report: List[dict] = []
_profile_data = {}

T = TypeVar("T", bound=Callable[..., Any])


class CustomJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, bytes):
            return base64.b64encode(obj).decode("utf-8")
        return super().default(obj)


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
    Record resources used by a StarknetContract and VM
    """

    _context = ""

    @classmethod
    @property
    def prefix(cls) -> str:
        """
        Prefix the log output with the context if used
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

        args_serializable = [_a.hex() if type(_a) == bytes else _a for _a in args]
        kwargs_serializable = {
            k: v.hex() if type(v) == bytes else v for k, v in kwargs.items()
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
        Wrapper to be applied to a contract's method to keep track of the ExecutionResources used.
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
                    setattr(prepared_call, "_traced", True)
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
                source = kwargs["source"]
            traceit.trace(contract, Path(source).stem)
            return contract

        return traced_deploy

    @classmethod
    @contextmanager
    def context(
        cls,
        context,
    ):
        """
        Context manager to add a context field to the logs and records
        """
        prev_context = cls._context
        cls._context = context
        yield
        cls._context = prev_context

    @classmethod
    def trace_run(cls, run):
        def _run(*args, **kwargs):
            runner, syscall_handler = run(*args, **kwargs)

            if cls._context:
                _profile_data[cls._context] = runner

            return runner, syscall_handler

        return _run


def reports():
    return (
        (
            pd.DataFrame(_time_report)
            .assign(
                contract=lambda df: df.kwargs.map(lambda kw: Path(kw["source"]).stem)
            )
            .reindex(columns=["contract", "name", "duration", "args", "kwargs"])
        ),
        (
            pd.DataFrame(_resources_report)
            .assign(context=lambda df: df.get("context", ""))
            .fillna({"context": ""})
            .sort_values(["n_steps"], ascending=False)
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
                        ).columns,
                        "args",
                        "kwargs",
                    ]
                )
            )
        ),
    )


def dump_reports(path: Union[str, Path]):
    p = Path(path)
    p.mkdir(exist_ok=True, parents=True)
    times, traces = reports()
    times.to_csv(p / "times.csv", index=False)
    traces.to_csv(p / "resources.csv", index=False)
    for label, runner in _profile_data.items():
        logger.info(f"Dumping TracerData for runner {label}")
        runner.relocate()
        tracer_data = TracerData(
            program=runner.program,
            memory=runner.relocated_memory,
            trace=runner.relocated_trace,
            program_base=1,
            debug_info=runner.get_relocated_debug_info(),
        )
        profile = profile_from_tracer_data(tracer_data)
        with open(p / f"{label}_prof.pb.gz", "wb") as fp:
            fp.write(profile)


def dump_coverage(path: Union[str, Path], files: List[CoverageFile]):
    json.dump(
        {
            "coverage": {
                str(Path(file.name).absolute().relative_to(Path(os.getcwd()))): {
                    **{l: 0 for l in file.missed},
                    **{l: 1 for l in file.covered},
                }
                for file in files
            }
        },
        open(Path(path) / "coverage.json", "w"),
        indent=2,
    )
