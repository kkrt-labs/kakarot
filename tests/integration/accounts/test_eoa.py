import pytest

from tests.utils.errors import kakarot_error


@pytest.mark.asyncio
class TestExternallyOwnedAccount:
    class TestGetEvmAddress:
        @pytest.mark.parametrize("address_idx", range(4))
        async def test_should_return_the_evm_address_used_at_deploy(
            self, addresses, address_idx
        ):
            address = addresses[address_idx]
            call_info = await address.starknet_contract.get_evm_address().call()
            assert call_info.result.evm_address == int(address.address, 16)

    class TestValidateDeclare:
        async def test_should_raise(self, owner):
            with kakarot_error():
                await owner.starknet_contract.__validate_declare__(0).call()

    async def test_bytecode(self, owner):
        assert (await owner.starknet_contract.bytecode().call()).result.bytecode == []

    async def test_bytecode_len(self, owner):
        assert (await owner.starknet_contract.bytecode_len().call()).result.len == 0