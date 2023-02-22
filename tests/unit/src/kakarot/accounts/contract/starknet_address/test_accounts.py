import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.helpers import generate_random_private_key


@pytest.mark.asyncio
class TestComputeStarknetAddress:
    async def test_should_return_same_as_deployed_address(
        self, kakarot: StarknetContract
    ):
        private_key = generate_random_private_key()
        evm_address = private_key.public_key.to_checksum_address()
        eoa_deploy_tx = await kakarot.deploy_externally_owned_account(
            int(evm_address, 16)
        ).execute()

        kakarot_starknet_address = eoa_deploy_tx.call_info.internal_calls[
            0
        ].contract_address

        computed_starknet_address = (
            (await kakarot.compute_starknet_address(evm_address=int(evm_address, 16)))
            .call()
            .result[0]
        )

        assert computed_starknet_address == kakarot_starknet_address
