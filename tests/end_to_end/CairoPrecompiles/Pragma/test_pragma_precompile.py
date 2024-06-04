from typing import OrderedDict, Tuple

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import EvmTransactionError
from kakarot_scripts.utils.starknet import get_deployments, wait_for_transaction

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


@pytest.fixture(autouse=True)
async def setup(get_contract, invoke, mocked_values, pragma_caller, max_fee):
    pragma_oracle = get_contract("MockPragmaOracle")
    tx = await pragma_oracle.functions["set_price"].invoke_v1(
        *mocked_values,
        max_fee=max_fee,
    )
    await wait_for_transaction(tx.hash)
    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(pragma_caller.address, 16),
        True,
    )


@pytest_asyncio.fixture(scope="module")
async def pragma_caller(deploy_contract, owner):
    pragma_oracle_address = get_deployments()["MockPragmaOracle"]["address"]
    return await deploy_contract(
        "CairoPrecompiles",
        "PragmaCaller",
        pragma_oracle_address,
        caller_eoa=owner.starknet_contract,
    )


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
        self, get_contract, pragma_caller, data_type, mocked_values, max_fee
    ):
        cairo_pragma = get_contract("MockPragmaOracle")
        (cairo_res,) = await cairo_pragma.functions["get_data_median"].call(data_type)
        solidity_input = serialize_data_type(data_type)
        sol_res = await pragma_caller.getDataMedianSpot(solidity_input)
        serialized_cairo_res = serialize_cairo_response(cairo_res)

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

        assert serialized_cairo_res == sol_res
        assert res_price == mocked_price
        assert res_decimals == mocked_decimals
        assert res_last_updated_timestamp == mocked_last_updated_timestamp
        assert res_num_sources_aggregated == mocked_num_sources_aggregated

        if data_type.get("FutureEntry"):
            assert (
                res_maybe_expiration_timestamp
                == mocked_last_updated_timestamp
                + 1000  # behavior coded inside the mock
            )
        else:
            assert res_maybe_expiration_timestamp == 0

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
        ],
    )
    async def test_should_fail_unauthorized_caller(
        self, get_contract, pragma_caller, invoke, data_type, max_fee, mocked_values
    ):
        await invoke(
            "kakarot",
            "set_authorized_cairo_precompile_caller",
            int(pragma_caller.address, 16),
            False,
        )
        cairo_pragma = get_contract("MockPragmaOracle")
        (cairo_res,) = await cairo_pragma.functions["get_data_median"].call(data_type)
        solidity_input = serialize_data_type(data_type)

        with pytest.raises(EvmTransactionError) as e:
            await pragma_caller.getDataMedianSpot(solidity_input)
        assert "CairoLib: call_contract failed" in str(e.value)
