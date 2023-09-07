import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.utils.uint256 import int_to_uint256


@pytest.mark.asyncio
@pytest.mark.EF_TEST
@pytest.mark.SLOAD
class TestSLOAD:
    # https://github.com/kkrt-labs/kakarot/issues/732
    @pytest.mark.xfail(
        reason="""
            Bytecode calls GAS and then stores it. Gas accounting is
            currently dysfunctional, marking this to fix later.
        """
    )
    async def test_sloadGasCost_d0g0v0_Shanghai(
        self,
        owner,
        create_account_with_bytecode_and_storage,
        kakarot: StarknetContract,
    ):
        called_contract = await create_account_with_bytecode_and_storage(
            "0x5a80545a905090036005900360015500",
        )

        # Send tx
        await kakarot.eth_send_transaction(
            to=int(called_contract.evm_contract_address, 16),
            gas_limit=100_000_000,
            gas_price=0,
            value=0,
            data=[],
        ).execute(caller_address=owner.starknet_address)

        storage_final = (
            await called_contract.storage(int_to_uint256(1)).call()
        ).result.value
        assert storage_final == int_to_uint256(0x834)
