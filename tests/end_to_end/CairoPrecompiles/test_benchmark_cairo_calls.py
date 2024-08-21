import json

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.starknet import get_contract, invoke


@pytest_asyncio.fixture(scope="module")
def benchmark_results():
    results = {"fixed_tx_cost": {}, "input_sizes": [], "output_sizes": []}
    yield results
    # Save all results at once after all tests have run
    with open("kakarot_scripts/data/cairo_calls_benchmark_results.json", "w") as f:
        json.dump(results, f, indent=2)


@pytest_asyncio.fixture()
async def cairo_contract(max_fee, deployer):
    return get_contract("BenchmarkCairoCalls", provider=deployer)


@pytest_asyncio.fixture()
async def cairo_contract_caller(owner, cairo_contract):
    caller_contract = await deploy(
        "CairoPrecompiles",
        "BenchmarkCairoCalls",
        cairo_contract.address,
        caller_eoa=owner.starknet_contract,
    )
    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(caller_contract.address, 16),
        True,
    )
    return caller_contract


@pytest.mark.asyncio(scope="module")
@pytest.mark.skip(reason="Use only for benchmarking")
class TestBenchmarkCairoCalls:
    async def test_benchmark_fixed_tx_cost(
        self, cairo_contract_caller, benchmark_results
    ):
        result = await cairo_contract_caller.empty()
        benchmark_results["fixed_tx_cost"] = {
            "gas_used": result["gas_used"],
            "steps": result["receipt"].execution_resources.steps,
            "memory_holes": result["receipt"].execution_resources.memory_holes,
            "range_check_builtin_applications": result[
                "receipt"
            ].execution_resources.range_check_builtin_applications,
            "pedersen_builtin_applications": result[
                "receipt"
            ].execution_resources.pedersen_builtin_applications,
            "ec_op_builtin_applications": result[
                "receipt"
            ].execution_resources.ec_op_builtin_applications,
            "bitwise_builtin_applications": result[
                "receipt"
            ].execution_resources.bitwise_builtin_applications,
            "keccak_builtin_applications": result[
                "receipt"
            ].execution_resources.keccak_builtin_applications,
        }

    @pytest.mark.parametrize(
        "n_inputs", [1, 2, 3, 4, 5, 10, 15, 20, 30, 40, 50, 75, 100]
    )
    async def test_benchmark_input_sizes(
        self, cairo_contract, cairo_contract_caller, n_inputs, benchmark_results
    ):
        result = await cairo_contract_caller.callCairoWithFeltInputs(n_inputs)
        benchmark_data = {
            "n_inputs": n_inputs,
            "gas_used": result["gas_used"],
            "steps": result["receipt"].execution_resources.steps,
            "memory_holes": result["receipt"].execution_resources.memory_holes,
            "range_check_builtin_applications": result[
                "receipt"
            ].execution_resources.range_check_builtin_applications,
            "pedersen_builtin_applications": result[
                "receipt"
            ].execution_resources.pedersen_builtin_applications,
            "ec_op_builtin_applications": result[
                "receipt"
            ].execution_resources.ec_op_builtin_applications,
            "bitwise_builtin_applications": result[
                "receipt"
            ].execution_resources.bitwise_builtin_applications,
            "keccak_builtin_applications": result[
                "receipt"
            ].execution_resources.keccak_builtin_applications,
        }
        benchmark_results["input_sizes"].append(benchmark_data)

    @pytest.mark.parametrize("n_bytes_output", [0, 31, 62, 93, 124, 155, 186, 217, 248])
    async def test_benchmark_output_sizes(
        self, cairo_contract, cairo_contract_caller, n_bytes_output, benchmark_results
    ):
        result = await cairo_contract_caller.callCairoWithBytesOutput(n_bytes_output)
        benchmark_data = {
            "n_bytes_output": n_bytes_output,
            "gas_used": result["gas_used"],
            "steps": result["receipt"].execution_resources.steps,
            "memory_holes": result["receipt"].execution_resources.memory_holes,
            "range_check_builtin_applications": result[
                "receipt"
            ].execution_resources.range_check_builtin_applications,
            "pedersen_builtin_applications": result[
                "receipt"
            ].execution_resources.pedersen_builtin_applications,
            "ec_op_builtin_applications": result[
                "receipt"
            ].execution_resources.ec_op_builtin_applications,
            "bitwise_builtin_applications": result[
                "receipt"
            ].execution_resources.bitwise_builtin_applications,
            "keccak_builtin_applications": result[
                "receipt"
            ].execution_resources.keccak_builtin_applications,
        }
        benchmark_results["output_sizes"].append(benchmark_data)
