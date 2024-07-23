from typing import OrderedDict, Tuple

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.starknet import get_contract, get_deployments, invoke
from tests.utils.errors import evm_error

ENTRY_TYPE_INDEX = {"SpotEntry": 0, "FutureEntry": 1, "GenericEntry": 2}


def serialize_cairo_response(cairo_dict: OrderedDict) -> Tuple:
    """
    Serialize the return data of a Cairo call to a tuple
    with the same format as the one returned by the Solidity contract.
    """
    # A None value in the Cairo response is equivalent to a value 0 in the Solidity response.
    return tuple(value if value is not None else 0 for value in cairo_dict.values())


def serialize_data_type(data_type: dict) -> Tuple:
    """
    Serialize the data type to a tuple
    with the same format as the one expected by the Solidity contract.

    In solidity, the serialized data type is a tuple with the following format:
    (entry_type, pair_id, expiration_timestamp)
      - SpotEntry and GenericEntry take one argument pair_id
      - FutureEntry takes two arguments pair_id and expiration_timestamp

    The `expiration_timestamp` is set to 0 for SpotEntry and GenericEntry.
    """
    entry_type, query_args = next(iter(data_type.items()))
    serialized_entry_type = ENTRY_TYPE_INDEX[entry_type]

    if isinstance(query_args, tuple):
        pair_id, expiration_timestamp = query_args
        return (serialized_entry_type, pair_id, expiration_timestamp)
    else:
        return (serialized_entry_type, query_args, 0)


@pytest_asyncio.fixture(scope="module")
async def pragma_caller(owner):
    pragma_oracle_address = get_deployments()["MockPragmaOracle"]["address"]
    return await deploy(
        "CairoPrecompiles",
        "PragmaCaller",
        pragma_oracle_address,
        caller_eoa=owner.starknet_contract,
    )


@pytest_asyncio.fixture()
async def cairo_pragma(mocked_values, pragma_caller):
    await invoke("MockPragmaOracle", "set_price", *mocked_values)
    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(pragma_caller.address, 16),
        True,
    )
    return get_contract("MockPragmaOracle")


@pytest.mark.asyncio(scope="module")
@pytest.mark.CairoPrecompiles
class TestPragmaPrecompile:

    @pytest.mark.parametrize(
        "data_type, mocked_values",
        [
            (
                {"SpotEntry": int.from_bytes(b"BTC/USD", byteorder="big")},
                (
                    int.from_bytes(b"BTC/USD", byteorder="big"),
                    70000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                {"FutureEntry": (int.from_bytes(b"ETH/USD", byteorder="big"), 0)},
                (
                    int.from_bytes(b"ETH/USD", byteorder="big"),
                    4000,
                    18,
                    1717143838,
                    1,
                ),
            ),
            (
                {"GenericEntry": int.from_bytes(b"SOL/USD", byteorder="big")},
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
        self, cairo_pragma, pragma_caller, data_type, mocked_values, max_fee
    ):
        (cairo_res,) = await cairo_pragma.functions["get_data_median"].call(data_type)
        solidity_input = serialize_data_type(data_type)
        sol_res = await pragma_caller.getDataMedianSpot(solidity_input)
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
            if data_type.get("FutureEntry")
            else 0
        )

    @pytest.mark.parametrize(
        "data_type", [{"SpotEntry": int.from_bytes(b"BTC/USD", byteorder="big")}]
    )
    async def test_should_fail_unauthorized_caller(self, pragma_caller, data_type):
        await invoke(
            "kakarot",
            "set_authorized_cairo_precompile_caller",
            int(pragma_caller.address, 16),
            False,
        )
        solidity_input = serialize_data_type(data_type)

        with evm_error("CairoLib: call_contract failed"):
            await pragma_caller.getDataMedianSpot(solidity_input)
