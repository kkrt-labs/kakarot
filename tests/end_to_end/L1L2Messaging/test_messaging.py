import pytest
import pytest_asyncio

from kakarot_scripts.utils.l1 import deploy_on_l1
from kakarot_scripts.utils.starknet import get_deployments, invoke


@pytest.fixture(scope="session")
async def setup_l1_messaging():
    starknet_messaging_l1 = await deploy_on_l1(
        "L1L2Messaging", "StarknetMessagingLocal"
    )
    return starknet_messaging_l1


@pytest_asyncio.fixture(scope="session")
async def message_sender_l2(deploy_contract, owner):
    cairo_messaging_address = get_deployments()["CairoMessaging"]["address"]
    message_sender = await deploy_contract(
        "L1L2Messaging",
        "MessageSenderL2",
        cairo_messaging_address,
        caller_eoa=owner.starknet_contract,
    )

    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(message_sender.address, 16),
        True,
    )
    return message_sender


async def test_should_send_message_to_l1(setup_l1_messaging, message_sender_l2):
    await message_sender_l2.sendMessageToL1()
    breakpoint()
