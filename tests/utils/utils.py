from starkware.cairo.lang.tracer.profile import profile_from_tracer_data
from starkware.cairo.lang.tracer.tracer_data import TracerData
from starkware.starknet.business_logic.execution.execute_entry_point import (
    ExecuteEntryPoint,
)

# Override _run() entrypoint for hooking and profiling cairo runner.
old_run = ExecuteEntryPoint._run


def override_run(*args, **kwargs):
    runner, syscall_handler = old_run(*args, **kwargs)

    if traceit._context:
        runner.relocate()

        tracer_data = TracerData(
            program=runner.program,
            memory=runner.relocated_memory,
            trace=runner.relocated_trace,
            program_base=1,
            debug_info=runner.get_relocated_debug_info(),
        )

        profile = profile_from_tracer_data(tracer_data)
        _profile_datas[traceit._context] = profile
    return runner, syscall_handler


ExecuteEntryPoint._run = override_run


import json
import logging
import os
from contextlib import contextmanager
from functools import wraps
from pathlib import Path
from textwrap import wrap
from time import perf_counter
from typing import (
    Any,
    Awaitable,
    Callable,
    Coroutine,
    Iterable,
    List,
    TypeVar,
    Union,
    cast,
)

import pandas as pd
from cairo_coverage.cairo_coverage import CoverageFile
from starkware.starknet.testing.objects import StarknetCallInfo
from starkware.starknet.testing.starknet import StarknetContract
from web3 import Web3
from web3._utils.abi import map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.contract import Contract

logging.basicConfig(format="%(levelname)-8s %(message)s")
logger = logging.getLogger("timer")

_time_report: List[dict] = []
_resources_report: List[dict] = []
_profile_datas = {}

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
    Record resources used by a StarknetContract
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
    for label, data in _profile_datas.items():
        with open(p / f"{label}_prof.pb.gz", "wb") as fp:
            fp.write(data)


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


def int_to_uint256(value):
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return low, high


def hex_string_to_bytes_array(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")
    if h[:2] == "0x":
        h = h[2:]
    return [int(b, 16) for b in wrap(h, 2)]


def bytes_array_to_bytes32_array(bytes_array: List[int]):
    return wrap("".join([hex(b)[2:] for b in bytes_array]), 64)


def wrap_for_kakarot(
    contract: Contract, kakarot: StarknetContract, evm_contract_address: int
):
    """
    Wrap a web3.contract to use kakarot as backend.
    """

    def wrap_zk_evm(fun: str, evm_contract_address: int):
        """
        Decorator to update contract.fun to target kakarot instead.
        """

        async def _wrapped(contract, *args, **kwargs):
            abi = contract.get_function_by_name(fun).abi
            if abi["stateMutability"] == "view":
                call = kakarot.execute_at_address(
                    address=evm_contract_address,
                    value=0,
                    calldata=hex_string_to_bytes_array(
                        contract.encodeABI(fun, args, kwargs)
                    ),
                )
                res = await call.call()
            else:
                caller_address = kwargs["caller_address"]
                del kwargs["caller_address"]
                if "value" in kwargs:
                    value = kwargs["value"]
                    del kwargs["value"]
                else:
                    value = 0
                call = kakarot.execute_at_address(
                    address=evm_contract_address,
                    value=value,
                    calldata=hex_string_to_bytes_array(
                        contract.encodeABI(fun, args, kwargs)
                    ),
                )
                res = await call.execute(caller_address=caller_address)
            if call._traced:
                traceit.pop_record()
                traceit.record_tx(
                    res,
                    contract_name=contract._contract_name,
                    attr_name=fun,
                    args=args,
                    kwargs=kwargs,
                )
            types = [o["type"] for o in abi["outputs"]]
            data = bytearray(res.result.return_data)
            decoded = Web3().codec.decode(types, data)
            normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
            return normalized[0] if len(normalized) == 1 else normalized

        return _wrapped

    for fun in contract.functions:
        setattr(
            contract,
            fun,
            classmethod(wrap_zk_evm(fun, evm_contract_address)),
        )
    return contract


def get_contract(contract_name: str) -> Contract:
    """
    Return a web3.contract instance based on the corresponding solidity files
    defined in tests/solidity_files.
    """
    solidity_output_path = Path("tests") / "solidity_files" / "output"
    abi = json.load(open(solidity_output_path / f"{contract_name}.abi"))
    bytecode = (solidity_output_path / f"{contract_name}.bin").read_text()
    contract = Web3().eth.contract(abi=abi, bytecode=bytecode)
    setattr(contract, "_contract_name", contract_name)
    return cast(Contract, contract)


def extract_memory_from_execute(result):
    mem = [0] * result.memory_bytes_len
    for i in range(0, len(result.memory_accesses), 3):
        k = result.memory_accesses[i]  # Word index.
        assert result.memory_accesses[i + 1] == 0  # Initial value.
        v = result.memory_accesses[i + 2]  # Final value.
        for j in range(16):
            if k * 16 + 15 - j < len(mem):
                mem[k * 16 + 15 - j] = v % 256
            else:
                assert v == 0
            v //= 256
    return mem


def extract_stack_from_execute(result):
    stack = [0] * int(result.stack_len / 2)
    for i in range(0, result.stack_len * 3, 6):
        k = result.stack_accesses[i]  # Word index.
        index = int(k / 2)
        assert result.stack_accesses[i + 1] == 0  # Initial value.
        high = result.stack_accesses[i + 2]  # Final value.
        assert result.stack_accesses[i + 4] == 0  # Initial value.
        low = result.stack_accesses[i + 5]  # Final value.
        stack[index] = 2**128 * high + low

    return stack
