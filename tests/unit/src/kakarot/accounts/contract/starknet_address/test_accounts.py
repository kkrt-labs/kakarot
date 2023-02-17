import pytest
from starkware.starknet.testing.starknet import Starknet

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.helpers import (
    generate_random_private_key,
)


@pytest.mark.asyncio
class TestStarknetAccount:
    async def test_compute_starknet_address(
        self, starknet: Starknet, kakarot: StarknetContract
    ):
        private_key = generate_random_private_key()
        evm_address = private_key.public_key.to_checksum_address()
        eoa_deploy_tx = await kakarot.deploy_externally_owned_account(
            int(evm_address, 16)
        ).execute()

        kakarot_starknet_address = eoa_deploy_tx.call_info.internal_calls[0].contract_address

        test_starknet_address_computation = await starknet.deploy(
            source="./tests/unit/src/kakarot/accounts/contract/starknet_address/test_accounts.cairo",
            cairo_path=["src"],
        )

        computed_starknet_address = (await test_starknet_address_computation.test__compute_starknet_address(evm_address=int(evm_address, 16)).call()).result[0]


        assert computed_starknet_address == kakarot_starknet_address
