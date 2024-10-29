from dataclasses import dataclass
from enum import Enum
from typing import Optional, OrderedDict, Tuple

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.starknet import get_contract, get_deployments, invoke


@dataclass
class Entry:
    key: int
    expiration_timestamp: Optional[int] = None
    is_generic: bool = False

    @property
    def entry_type(self) -> int:
        if self.is_generic:
            return 2
        return 0 if self.expiration_timestamp is None else 1

    def to_dict(self) -> dict:
        if self.expiration_timestamp is None:
            return {"SpotEntry": self.key}
        if self.is_generic:
            return {"GenericEntry": self.key}
        return {"FutureEntry": (self.key, self.expiration_timestamp)}

    def serialize(self) -> Tuple[int, int, int]:
        return (self.entry_type, self.key, self.expiration_timestamp or 0)


class AggregationMode(Enum):
    MEDIAN = "Median"
    MEAN = "Mean"

    def to_tuple(self) -> Tuple[str, None]:
        return (self.value, None)

    def serialize(self) -> int:
        return list(AggregationMode).index(self)


def serialize_cairo_response(cairo_dict: OrderedDict) -> Tuple:
    """
    Serialize the return data of a Cairo call to a tuple
    with the same format as the one returned by the Solidity contract.
    """
    # A None value in the Cairo response is equivalent to a value 0 in the Solidity response.
    return tuple(value if value is not None else 0 for value in cairo_dict.values())


def serialize_cairo_inputs(*args) -> List[int]:
    """
    Serialize the provided arguments to the same format as the one expected by
    the Solidity contract.
    Each arguments must be either:
        * an `Entry`,
        * an `AggregationMode`,
        * a `int`.
    """
    serialized_inputs = []
    for arg in args:
        if isinstance(arg, (AggregationMode, Entry)):
            serialized = arg.serialize()
            if isinstance(serialized, tuple):
                serialized_inputs.extend(serialized)
            else:
                serialized_inputs.append(serialized)
        elif isinstance(arg, int):
            serialized_inputs.append(arg)
        else:
            raise TypeError(
                f"Unsupported type: {type(arg)}. Must be AggregationMode, Entry, or int"
            )
    return serialized_inputs


@pytest_asyncio.fixture(scope="module")
async def pragma_caller(owner):
    pragma_summary_stats_address = get_deployments()["MockPragmaSummaryStats"]
    pragma_oracle_address = get_deployments()["MockPragmaOracle"]
    return await deploy(
        "CairoPrecompiles",
        "PragmaCaller",
        pragma_oracle_address,
        pragma_summary_stats_address,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture()
async def cairo_pragma_oracle(mocked_values, pragma_caller):
    await invoke("MockPragmaOracle", "set_price", *mocked_values)
    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(pragma_caller.address, 16),
        True,
    )
    return get_contract("MockPragmaOracle")


@pytest_asyncio.fixture()
async def cairo_pragma_summary_stats():
    return get_contract("MockPragmaSummaryStats")


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestPragmaPrecompile:

    @pytest.mark.parametrize(
        "data_type, aggregation_mode, mocked_values",
        [
            (
                Entry(key=int.from_bytes(b"BTC/USD", byteorder="big")),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"BTC/USD", byteorder="big"),
                    70000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                Entry(
                    key=int.from_bytes(b"ETH/USD", byteorder="big"),
                    expiration_timestamp=0,
                ),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"ETH/USD", byteorder="big"),
                    4000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                Entry(key=int.from_bytes(b"SOL/USD", byteorder="big"), is_generic=True),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"SOL/USD", byteorder="big"),
                    180,
                    18,
                    1717143838,
                    1,
                ),
            ),
        ],
    )
    async def test_should_return_data_median_for_query(
        self,
        cairo_pragma_oracle,
        pragma_caller,
        data_type,
        aggregation_mode,
        mocked_values,
        max_fee,
    ):
        (cairo_res,) = await cairo_pragma_oracle.functions["get_data"].call(
            data_type.to_dict(),
            aggregation_mode.to_tuple(),
        )
        solidity_input = serialize_cairo_inputs(aggregation_mode, data_type)
        sol_res = await pragma_caller.getData(solidity_input)
        serialized_cairo_res = serialize_cairo_response(cairo_res)
        assert serialized_cairo_res == sol_res

        (
            res_price,
            res_decimals,
            res_last_updated_timestamp,
            res_num_sources_aggregated,
            res_maybe_expiration_timestamp,
        ) = sol_res
        (
            _,
            mocked_price,
            mocked_decimals,
            mocked_last_updated_timestamp,
            mocked_num_sources_aggregated,
        ) = mocked_values
        assert res_price == mocked_price
        assert res_decimals == mocked_decimals
        assert res_last_updated_timestamp == mocked_last_updated_timestamp
        assert res_num_sources_aggregated == mocked_num_sources_aggregated

        assert res_maybe_expiration_timestamp == (
            # behavior coded inside the mock
            mocked_last_updated_timestamp + 1000
            if data_type.expiration_timestamp is not None
            else 0
        )

    @pytest.mark.parametrize(
        "data_type, aggregation_mode, mocked_values",
        [
            (
                Entry(key=int.from_bytes(b"BTC/USD", byteorder="big")),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"BTC/USD", byteorder="big"),
                    70000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                Entry(
                    key=int.from_bytes(b"ETH/USD", byteorder="big"),
                    expiration_timestamp=0,
                ),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"ETH/USD", byteorder="big"),
                    4000,
                    18,
                    1717143838,
                    1,
                ),
            ),
        ],
    )
    async def test_should_get_mean_for_query(
        self,
        cairo_pragma_oracle,
        cairo_pragma_summary_stats,
        pragma_caller,
        data_type,
        aggregation_mode,
        mocked_values,
        max_fee,
    ):
        (cairo_res,) = await cairo_pragma_summary_stats.functions[
            "calculate_mean"
        ].call(
            data_type.to_dict(),
            0,
            0,
            aggregation_mode.to_tuple(),
        )
        solidity_input = serialize_cairo_inputs(data_type, 0, 0, aggregation_mode)
        sol_res = await pragma_caller.calculateMean(solidity_input)
        serialized_cairo_res = serialize_cairo_response(cairo_res)
        assert serialized_cairo_res == sol_res

        (
            res_price,
            res_decimals,
        ) = sol_res
        (
            _,
            mocked_price,
            mocked_decimals,
        ) = mocked_values
        assert res_price == mocked_price
        assert res_decimals == mocked_decimals

    @pytest.mark.parametrize(
        "data_type, aggregation_mode, mocked_values",
        [
            (
                Entry(key=int.from_bytes(b"BTC/USD", byteorder="big")),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"BTC/USD", byteorder="big"),
                    70000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                Entry(
                    key=int.from_bytes(b"ETH/USD", byteorder="big"),
                    expiration_timestamp=0,
                ),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"ETH/USD", byteorder="big"),
                    4000,
                    18,
                    1717143838,
                    1,
                ),
            ),
        ],
    )
    async def test_should_get_volatility_for_query(
        self,
        cairo_pragma_oracle,
        cairo_pragma_summary_stats,
        pragma_caller,
        data_type,
        aggregation_mode,
        mocked_values,
        max_fee,
    ):
        (cairo_res,) = await cairo_pragma_summary_stats.functions[
            "calculate_volatility"
        ].call(
            data_type.to_dict(),
            0,
            0,
            0,
            aggregation_mode.to_tuple(),
        )
        solidity_input = serialize_cairo_inputs(data_type, 0, 0, 0, aggregation_mode)
        sol_res = await pragma_caller.calculateVolatility(solidity_input)
        serialized_cairo_res = serialize_cairo_response(cairo_res)
        assert serialized_cairo_res == sol_res

        (
            res_price,
            res_decimals,
        ) = sol_res
        (
            _,
            mocked_price,
            mocked_decimals,
        ) = mocked_values
        assert res_price == mocked_price
        assert res_decimals == mocked_decimals

    @pytest.mark.parametrize(
        "data_type, aggregation_mode, mocked_values",
        [
            (
                Entry(key=int.from_bytes(b"BTC/USD", byteorder="big")),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"BTC/USD", byteorder="big"),
                    70000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                Entry(
                    key=int.from_bytes(b"ETH/USD", byteorder="big"),
                    expiration_timestamp=0,
                ),
                AggregationMode.MEDIAN,
                (
                    int.from_bytes(b"ETH/USD", byteorder="big"),
                    4000,
                    18,
                    1717143838,
                    1,
                ),
            ),
        ],
    )
    async def test_should_get_twap_for_query(
        self,
        cairo_pragma_oracle,
        cairo_pragma_summary_stats,
        pragma_caller,
        data_type,
        aggregation_mode,
        mocked_values,
        max_fee,
    ):
        (cairo_res,) = await cairo_pragma_summary_stats.functions[
            "calculate_twap"
        ].call(
            data_type.to_dict(),
            aggregation_mode.to_tuple(),
            0,
            0,
        )
        solidity_input = serialize_cairo_inputs(data_type, aggregation_mode, 0, 0)
        sol_res = await pragma_caller.calculateTwap(solidity_input)
        serialized_cairo_res = serialize_cairo_response(cairo_res)
        assert serialized_cairo_res == sol_res

        (
            res_price,
            res_decimals,
        ) = sol_res
        (
            _,
            mocked_price,
            mocked_decimals,
        ) = mocked_values
        assert res_price == mocked_price
        assert res_decimals == mocked_decimals
