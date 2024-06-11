import asyncio

import pytest

from kakarot_scripts.utils.l1 import (
    dump_l1_addresses,
    get_l1_addresses,
    get_l1_contract,
    l1_contract_exists,
)
from kakarot_scripts.utils.starknet import get_deployments, invoke


@pytest.fixture(scope="session")
async def sn_messaging_local(deploy_l1_contract, owner):
    # If the contract is already deployed on the anvil instance, we can get the address from the deployments file
    # Otherwise, we deploy it

    l1_addresses = get_l1_addresses()
    if l1_addresses.get("StarknetMessagingLocal"):
        address = l1_addresses["StarknetMessagingLocal"]["address"]
        if l1_contract_exists(address):
            return get_l1_contract("L1L2Messaging", "StarknetMessagingLocal", address)

    contract = await deploy_l1_contract(
        "L1L2Messaging",
        "StarknetMessagingLocal",
    )
    l1_addresses.update({"StarknetMessagingLocal": {"address": contract.address}})
    dump_l1_addresses(l1_addresses)
    return contract


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


async def wait_for_message(sn_messaging_local):
    event_filter = sn_messaging_local.events.MessageHashesAddedFromL2.create_filter(
        fromBlock="latest"
    )
    while True:
        messages = event_filter.get_new_entries()
        if messages:
            return messages
        await asyncio.sleep(3)


async def test_should_send_message_to_l1(
    sn_messaging_local, l1_receiver, message_sender_l2
):
    await message_sender_l2.sendMessageToL1(l1_receiver.address, 42)
    await wait_for_message(sn_messaging_local)
    await l1_receiver.consumeMessage([42])
