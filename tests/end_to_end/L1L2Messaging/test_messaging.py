import time

import pytest

from kakarot_scripts.utils.starknet import get_deployments, invoke


@pytest.fixture(scope="session")
async def sn_messaging_local(deploy_l1_contract, owner):
    return await deploy_l1_contract(
        "L1L2Messaging",
        "StarknetMessagingLocal",
    )


@pytest.fixture(scope="session")
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


@pytest.fixture(scope="session")
async def l1_receiver(deploy_l1_contract, sn_messaging_local):
    cairo_messaging_address = get_deployments()["CairoMessaging"]["address"]
    return await deploy_l1_contract(
        "L1L2Messaging",
        "L1Receiver",
        sn_messaging_local.address,
        cairo_messaging_address,
    )


async def test_should_send_message_to_l1(
    sn_messaging_local, l1_receiver, message_sender_l2
):
    await message_sender_l2.sendMessageToL1(l1_receiver.address, 42)
    time.sleep(10)  # Wait for katana to propagate the message
    await l1_receiver.consumeMessage([42])
