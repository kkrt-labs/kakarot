import asyncio
import time

import pytest

from kakarot_scripts.utils.l1 import (
    dump_l1_addresses,
    get_l1_addresses,
    get_l1_contract,
    l1_contract_exists,
)
from kakarot_scripts.utils.starknet import get_deployments


@pytest.fixture(scope="session")
async def sn_messaging_local(deploy_l1_contract):
    # If the contract is already deployed on the l1, we can get the address from the deployments file
    # Otherwise, we deploy it
    l1_addresses = get_l1_addresses()
    if l1_addresses.get("StarknetMessagingLocal"):
        address = l1_addresses["StarknetMessagingLocal"]["address"]
        if l1_contract_exists(address):
            return get_l1_contract("starknet", "StarknetMessagingLocal", address)

    contract = await deploy_l1_contract(
        "starknet",
        "StarknetMessagingLocal",
    )
    l1_addresses.update({"StarknetMessagingLocal": {"address": contract.address}})
    dump_l1_addresses(l1_addresses)
    return contract


@pytest.fixture(scope="session")
async def l1_kakarot_messaging(sn_messaging_local, deploy_l1_contract, invoke):
    # If the contract is already deployed on the l1, we can get the address from the deployments file
    # Otherwise, we deploy it
    l1_addresses = get_l1_addresses()
    if l1_addresses.get("L1KakarotMessaging"):
        address = l1_addresses["L1KakarotMessaging"]["address"]
        if l1_contract_exists(address):
            return get_l1_contract("L1L2Messaging", "L1KakarotMessaging", address)

    kakarot_address = get_deployments()["kakarot"]["address"]
    contract = await deploy_l1_contract(
        "L1L2Messaging",
        "L1KakarotMessaging",
        sn_messaging_local.address,
        kakarot_address,
    )
    l1_addresses.update({"L1KakarotMessaging": {"address": contract.address}})
    dump_l1_addresses(l1_addresses)
    # Authorize the contract to send messages
    await invoke(
        "kakarot",
        "set_authorized_message_sender",
        int(contract.address, 16),
        True,
    )
    return contract


@pytest.fixture(scope="session")
async def message_app_l2(deploy_contract, owner):
    message_sender = await deploy_contract(
        "L1L2Messaging",
        "MessageAppL2",
        caller_eoa=owner.starknet_contract,
    )
    return message_sender


@pytest.fixture(scope="session")
async def message_app_l1(deploy_l1_contract, l1_kakarot_messaging):
    kakarot_address = get_deployments()["kakarot"]["address"]
    return await deploy_l1_contract(
        "L1L2Messaging",
        "MessageAppL1",
        l1_kakarot_messaging.address,
        kakarot_address,
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


@pytest.mark.asyncio(scope="module")
class TestL1ToL2Messages:
    async def test_should_increment_counter_on_l1(
        self, sn_messaging_local, message_app_l1, message_app_l2
    ):
        msg_counter_before = int(
            (await message_app_l1.receivedMessagesCounter()).hex(), 16
        )
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_message(sn_messaging_local)
        await message_app_l1.consumeCounterIncrease([increment_value])
        msg_counter_after = int(
            (await message_app_l1.receivedMessagesCounter()).hex(), 16
        )
        assert msg_counter_after == msg_counter_before + increment_value


@pytest.mark.asyncio(scope="module")
class TestL2ToL1Messages:
    async def test_should_increment_counter_on_l2(
        self, l1_kakarot_messaging, message_app_l1, message_app_l2
    ):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        increment_value = 1
        await message_app_l1.increaseL2AppCounter(
            message_app_l2.address, value=increment_value
        )
        time.sleep(4)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_fail_unauthorized_message_sender(
        self, invoke, l1_kakarot_messaging, message_app_l1, message_app_l2
    ):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        await invoke(
            "kakarot",
            "set_authorized_message_sender",
            int(l1_kakarot_messaging.address, 16),
            False,
        )
        await message_app_l1.increaseL2AppCounter(message_app_l2.address, value=1)
        time.sleep(4)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before
