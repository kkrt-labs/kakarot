import json
import logging
from pathlib import Path
from time import time
from typing import Union

import pandas as pd
from starkware.starknet.testing.starknet import StarknetContract

logging.basicConfig(format="%(levelname)-8s %(message)s")
logger = logging.getLogger("timer")


_time_report = []
_resources_report = []


def timeit(fun):
    async def timed_fun(*args, **kwargs):
        start = time()
        res = await fun(*args, **kwargs)
        stop = time()
        duration = stop - start
        _time_report.append(
            {"name": fun.__name__, "args": args, "kwargs": kwargs, "duration": duration}
        )
        logger.info(
            f"{fun.__name__}({json.dumps(args)}, {json.dumps(kwargs)}) in {duration:.2f}s"
        )
        return res

    return timed_fun


def _trace_call(fun, name, *args, **kwargs):
    async def traced_fun(*a, **kw):
        res = await fun(*a, **kw)
        _resources_report.append(
            {
                "name": name,
                "args": args,
                "kwargs": kwargs,
                "resources": res.call_info.execution_resources,
            }
        )
        logger.info(
            f"{name}({json.dumps(args)}, {json.dumps(kwargs)}) used {res.call_info.execution_resources}"
        )
        return res

    return traced_fun


def _trace_attr(fun, name):
    def wrapped(*args, **kwargs):
        prepared_call = fun(*args, **kwargs)
        for f_name in ["execute", "call"]:
            if hasattr(prepared_call, f_name):
                setattr(
                    prepared_call,
                    f_name,
                    _trace_call(
                        getattr(prepared_call, f_name),
                        f"{name}.{fun.__name__}",
                        *args,
                        **kwargs,
                    ),
                )
        return prepared_call

    return wrapped


def traceit(contract: StarknetContract, name: str):
    for attr_name in contract._abi_function_mapping.keys():
        setattr(
            contract,
            attr_name,
            _trace_attr(getattr(contract, attr_name), name),
        )
    return contract


def reports():
    return pd.DataFrame(_time_report), pd.DataFrame(_resources_report)


def dump_reports(path: Union[str, Path]):
    times, traces = reports()
    times.to_csv(Path(path) / "times.csv", index=False)
    traces.to_csv(Path(path) / "resources.csv", index=False)
