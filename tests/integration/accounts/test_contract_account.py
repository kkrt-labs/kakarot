import pytest

from starkware.starknet.testing.contract import StarknetContract


@pytest.mark.asyncio
class TestContractAccount:
    class TestIncreaseNonce:
        async def test_should_increment_nonce(
            self, contract_account: StarknetContract, kakarot
        ):
            # Get current contract account nonce
            initial_nonce = (await contract_account.get_nonce.call()).result.nonce
            # Store bytecode that includes CREATE opcode
            contract_account.write_bytecode(["0x60","0","0x60","offset","0x60","size","0xf0",]).execute(
                caller_address=kakarot.contract_address
            )
            # Run bytecode
            kakarot.execute_at_address(
                address=contract_account.contract_address,
                value=0,
                gas_limit=0,
                calldata=[],
            )
            # Get new nonce
            assert initial_nonce == (await contract_account.get_nonce().call()).result.nonce
