import json
import logging
from contextlib import contextmanager
from pathlib import Path
from time import perf_counter
from typing import Union

import pandas as pd
from starkware.starknet.testing.starknet import StarknetContract

logging.basicConfig(format="%(levelname)-8s %(message)s")
logger = logging.getLogger("timer")


_time_report = []
_resources_report = []


def timeit(fun):
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

    return timed_fun


class traceit:

    _context = ""

    @classmethod
    @property
    def prefix(cls):
        return cls._context + ":" if cls._context != "" else ""

    @classmethod
    def _trace_call(cls, invoke_fun, contract_name, attr_name, *args, **kwargs):
        async def traced_fun(*a, **kw):
            res = await invoke_fun(*a, **kw)
            resources = res.call_info.execution_resources.Schema().dump(
                res.call_info.execution_resources
            )
            resources = {
                **resources.pop("builtin_instance_counter"),
                **resources,
            }
            _resources_report.append(
                {
                    **({"context": cls._context} if cls._context != "" else {}),
                    "contract_name": contract_name,
                    "function_name": attr_name,
                    "args": args,
                    "kwargs": kwargs,
                    **resources,
                }
            )
            logger.info(
                f"{cls.prefix}{contract_name}.{attr_name}({json.dumps(args)}, {json.dumps(kwargs)}) used {resources}"
            )
            return res

        return traced_fun

    @classmethod
    def _trace_attr(cls, fun, contract_name):
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

    @classmethod
    @contextmanager
    def context(
        cls,
        context,
    ):
        prev_context = cls._context
        cls._context = context
        yield
        cls._context = prev_context


def reports():
    return pd.DataFrame(_time_report), pd.DataFrame(_resources_report).sort_values(
        ["n_steps"], ascending=False
    ).fillna({"context": ""}).fillna(0)


def dump_reports(path: Union[str, Path]):
    p = Path(path)
    p.mkdir(exist_ok=True, parents=True)
    times, traces = reports()
    times.to_csv(p / "times.csv")
    traces.to_csv(p / "resources.csv")
