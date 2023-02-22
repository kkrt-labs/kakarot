import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.integration.bytecode.test_cases import test_cases
from tests.utils.helpers import (
    extract_memory_from_execute,
    extract_stack_from_execute,
    hex_string_to_bytes_array,
    generate_random_private_key,
)
from tests.utils.reporting import traceit

params_execute = [pytest.param(case.pop("params"), **case) for case in test_cases]


@pytest.mark.asyncio
class TestKakarot:
    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(
        self,
        kakarot: StarknetContract,
        owner,
        params: dict,
        request,
    ):
        # TODO Call with MockSigner for TxInfo to be set with the right caller
        with traceit.context(request.node.callspec.id):
            res = await kakarot.execute(
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
                    event.keys,
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events

    class TestComputeStarknetAddress:
        async def test_should_return_same_as_deployed_address(
            self, kakarot: StarknetContract
        ):
            private_key = generate_random_private_key()
            evm_address = private_key.public_key.to_checksum_address()
            eoa_deploy_tx = await kakarot.deploy_externally_owned_account(
                int(evm_address, 16)
            ).execute()

            kakarot_starknet_address = eoa_deploy_tx.call_info.internal_calls[0].contract_address

            computed_starknet_address = (await kakarot.compute_starknet_address(evm_address=int(evm_address, 16)).call()).result[0]

            assert kakarot_starknet_address == computed_starknet_address
