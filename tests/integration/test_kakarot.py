import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.integration.bytecodes import test_cases
from tests.utils.accounts import fund_evm_address
from tests.utils.helpers import (
    extract_memory_from_execute,
    extract_stack_from_execute,
    generate_random_evm_address,
    hex_string_to_bytes_array,
)
from tests.utils.reporting import traceit


@pytest_asyncio.fixture(scope="session")
async def evm(
    starknet: Starknet,
    eth: StarknetContract,
    contract_account_class: DeclaredClass,
    account_proxy_class: DeclaredClass,
    blockhash_registry: StarknetContract,
) -> StarknetContract:
    class_hash = await starknet.deprecated_declare(
        source="./tests/fixtures/EVM.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    return await starknet.deploy(
        class_hash=class_hash.class_hash,
        constructor_calldata=[
            eth.contract_address,  # native_token_address_
            contract_account_class.class_hash,  # contract_account_class_hash_
            account_proxy_class.class_hash,  # account_proxy_class_hash
            blockhash_registry.contract_address,  # blockhash_registry_address_
        ],
    )


params_execute = [pytest.param(case.pop("params"), **case) for case in test_cases]


@pytest.mark.asyncio
class TestKakarot:
    class TestComputeStarknetAddress:
        async def test_should_return_same_as_deployed_address(
            self, kakarot: StarknetContract, eth: StarknetContract
        ):
            evm_address = int(generate_random_evm_address(), 16)
            await fund_evm_address(evm_address, kakarot, eth)

            deployed_starknet_address = (
                (await kakarot.deploy_externally_owned_account(evm_address).execute())
                .call_info.internal_calls[0]
                .contract_address
            )

            computed_starknet_address = (
                await kakarot.compute_starknet_address(evm_address).call()
            ).result[0]

            assert deployed_starknet_address == computed_starknet_address

    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(
        self,
        evm: StarknetContract,
        owner,
        params: dict,
        request,
    ):
        # TODO Call with MockSigner for TxInfo to be set with the right caller
        with traceit.context(request.node.callspec.id):
            res = await evm.execute(
                value=int(params["value"]),
                bytecode=hex_string_to_bytes_array(params["code"]),
                calldata=hex_string_to_bytes_array(params["calldata"]),
            ).call(caller_address=owner.starknet_address)

        stack_result = extract_stack_from_execute(res.result)
        memory_result = extract_memory_from_execute(res.result)

        assert stack_result == (
            [int(x) for x in params["stack"].split(",")] if params["stack"] else []
        )
        assert memory_result == hex_string_to_bytes_array(params["memory"])

        events = params.get("events")
        if events:
            assert [
                [
                    # we remove the key that is used to convey the emitting kkrt evm contract
                    event.keys[:-1],
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events
