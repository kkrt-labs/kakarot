import json
import logging
from contextlib import contextmanager
from pathlib import Path
from textwrap import wrap
from time import perf_counter
from typing import Callable, List, Union

import pandas as pd
from starkware.starknet.testing.starknet import StarknetContract
from web3 import Web3
from web3._utils.abi import map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS

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
    """
    Record resources used by a StarknetContract
    """

    _context = ""

    @classmethod
    @property
    def prefix(cls):
        """
        Prefix the log output with the context if used
        """
        return cls._context + ":" if cls._context != "" else ""

    @classmethod
    def _trace_call(
        cls,
        invoke_fun: Callable,
        contract_name: str,
        attr_name: str,
        *args,
        **kwargs,
    ):
        """
        StarknetContract instances have methods defined in their corresponding cairo file.
        These methods, once called, return a StarknetContractFunctionInvocation instance.
        This class defines "call" and "execute" methods for view or external call to the underlying functions.
        The invoke_fun here is either one or the other.
        This wrapper will record the ExecutionResource of the corresponding call.
        """

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
    def trace_all(deploy: Callable):
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
        pd.DataFrame(_time_report)
        .assign(contract=lambda df: df.kwargs.map(lambda kw: Path(kw["source"]).stem))
        .reindex(columns=["contract", "name", "duration", "args", "kwargs"]),
        pd.DataFrame(_resources_report)
        .sort_values(["n_steps"], ascending=False)
        .fillna({"context": ""})
        .fillna(0)
        .pipe(
            lambda df: df.reindex(
                columns=[
                    "context",
                    "contract_name",
                    "function_name",
                    *df.drop(
                        ["context", "contract_name", "function_name", "args", "kwargs"],
                        axis=1,
                    ).columns,
                    "args",
                    "kwargs",
                ]
            )
        ),
    )


def dump_reports(path: Union[str, Path]):
    p = Path(path)
    p.mkdir(exist_ok=True, parents=True)
    times, traces = reports()
    times.to_csv(p / "times.csv", index=False)
    traces.to_csv(p / "resources.csv", index=False)


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

def hex_string_to_felt_packed_array(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")
    if h[:2] == "0x":
        h = h[2:]
    h_len = len(h)
    h_remainder = (62 - h_len % 62)
    h_final = h.ljust(h_len+h_remainder,'0')
    return [int(b, 16) for b in wrap(h_final, 62)]

def bytecode_len(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")
    if h[:2] == "0x":
        h = h[2:]
    return int(len(h)/2)


def bytes_array_to_bytes32_array(bytes_array: List[int]):
    return wrap("".join([hex(b)[2:] for b in bytes_array]), 64)


def wrap_for_kakarot(contract, kakarot, evm_contract_address):
    """
    Wrap a web3.contract to use kakarot as backend.
    """

    def wrap_zk_evm(fun, evm_contract_address):
        """
        Decorator to update contract.fun to target kakarot instead.
        """

        async def _wrapped(contract, *args, **kwargs):
            abi = contract.get_function_by_name(fun).abi
            if abi["stateMutability"] == "view":
                res = await kakarot.execute_at_address(
                    address=evm_contract_address,
                    value=kwargs.get("value", 0),
                    calldata=hex_string_to_felt_packed_array(
                        contract.encodeABI(fun, args, kwargs)
                    ),
                    original_calldata_len=bytecode_len(contract.encodeABI(fun, args, kwargs)),
                ).call()
            else:
                caller_address = kwargs["caller_address"]
                del kwargs["caller_address"]
                res = await kakarot.execute_at_address(
                    address=evm_contract_address,
                    value=kwargs.get("value", 0),
                    calldata=hex_string_to_felt_packed_array(
                        contract.encodeABI(fun, args, kwargs)
                    ),
                    original_calldata_len=bytecode_len(contract.encodeABI(fun, args, kwargs)),
                ).execute(caller_address=caller_address)
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


def get_contract(contract_name):
    """
    Return a web3.contract instance based on the corresponding solidity files
    defined in tests/solidity_files.
    """
    solidity_output_path = Path("tests") / "solidity_files" / "output"
    abi = json.load(open(solidity_output_path / f"{contract_name}.abi"))
    bytecode = (solidity_output_path / f"{contract_name}.bin").read_text()
    return Web3().eth.contract(abi=abi, bytecode=bytecode)
