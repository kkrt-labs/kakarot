import pytest
import pytest_asyncio
from eth_utils.address import to_checksum_address

from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments


@pytest_asyncio.fixture(scope="function")
async def messaging_hack_contract(owner):
    return await deploy(
        "NoDelegateCallTesting",
        "L2MessagingHack",
        _target=to_checksum_address(
            get_evm_deployments()["L2KakarotMessaging"]["address"]
        ),
        caller_eoa=owner.starknet_contract,
    )


@pytest.mark.asyncio(scope="module")
class TestL2MessagingHack:
    async def test_malicious_message_should_fail_nodelegatecall(
        self,
        messaging_hack_contract,
    ):
        malicious_target = "0x1234567890123456789012345678901234567890"
        malicious_data = "0xdeadbeef"

        result = await messaging_hack_contract.functions[
            "trySendMessageToL1(address,bytes)"
        ](malicious_target, malicious_data)
        assert result["success"] == 1
        underlying_call_succeeded = int.from_bytes(bytes(result["response"]), "big")
        assert underlying_call_succeeded == 0
