import asyncio
import time

import pytest
import pytest_asyncio

from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.l1 import (
    deploy_on_l1,
    dump_l1_addresses,
    get_l1_addresses,
    get_l1_contract,
    l1_contract_exists,
)
from kakarot_scripts.utils.starknet import invoke
from tests.utils.errors import evm_error


@pytest.fixture(scope="session")
def sn_messaging_local():
    # If the contract is already deployed on the l1, we can get the address from the deployments file
    # Otherwise, we deploy it
    l1_addresses = get_l1_addresses()
    if l1_addresses.get("StarknetMessagingLocal"):
        address = l1_addresses["StarknetMessagingLocal"]["address"]
        if l1_contract_exists(address):
            return get_l1_contract("starknet", "StarknetMessagingLocal", address)

    contract = deploy_on_l1(
        "starknet",
        "StarknetMessagingLocal",
    )
    l1_addresses.update({"StarknetMessagingLocal": {"address": contract.address}})
    dump_l1_addresses(l1_addresses)
    return contract


@pytest_asyncio.fixture(scope="session")
async def l1_kakarot_messaging(sn_messaging_local, kakarot):
    # If the contract is already deployed on the l1, we can get the address from the deployments file
    # Otherwise, we deploy it
    l1_addresses = get_l1_addresses()
    contract = deploy_on_l1(
        "L1L2Messaging",
        "L1KakarotMessaging",
        starknetMessaging_=sn_messaging_local.address,
        kakarotAddress_=kakarot.address,
    )
    l1_addresses.update({"L1KakarotMessaging": {"address": contract.address}})
    dump_l1_addresses(l1_addresses)
    # Authorize the contract to send messages
    await invoke(
        "kakarot", "set_l1_messaging_contract_address", int(contract.address, 16)
    )
    return contract


@pytest_asyncio.fixture(scope="session")
async def l2KakarotMessaging(kakarot):
    l2KakarotMessaging = await deploy("L1L2Messaging", "L2KakarotMessaging")
    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(l2KakarotMessaging.address, 16),
        True,
    )
    return l2KakarotMessaging


@pytest_asyncio.fixture(scope="session")
async def message_app_l2(owner, l2KakarotMessaging):
    return await deploy(
        "L1L2Messaging",
        "MessageAppL2",
        _l2KakarotMessaging=l2KakarotMessaging.address,
        caller_eoa=owner.starknet_contract,
    )


@pytest.fixture(scope="session")
def message_app_l1(sn_messaging_local, l1_kakarot_messaging, kakarot):
    return deploy_on_l1(
        "L1L2Messaging",
        "MessageAppL1",
        starknetMessaging=sn_messaging_local.address,
        l1KakarotMessaging=l1_kakarot_messaging.address,
        kakarotAddress=kakarot.address,
    )


@pytest.fixture(scope="function")
def wait_for_sn_messaging_local(sn_messaging_local):

    async def _factory():
        event_filter_sn_messaging_local = (
            sn_messaging_local.events.MessageHashesAddedFromL2.create_filter(
                fromBlock="latest"
            )
        )
        while True:
            messages = event_filter_sn_messaging_local.get_new_entries()
            if messages:
                return messages
            await asyncio.sleep(1)

    return _factory


@pytest.mark.slow
@pytest.mark.asyncio(scope="module")
class TestL2ToL1Messages:
    async def test_should_increment_counter_on_l1(
        self,
        message_app_l1,
        message_app_l2,
        wait_for_sn_messaging_local,
    ):
        msg_counter_before = message_app_l1.receivedMessagesCounter()
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_sn_messaging_local()
        message_payload = increment_value.to_bytes(32, "big")
        message_app_l1.consumeCounterIncrease(message_app_l2.address, message_payload)
        msg_counter_after = message_app_l1.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_fail_unauthorized_message_sender(
        self,
        message_app_l1,
        message_app_l2,
        l1_kakarot_messaging,
        wait_for_sn_messaging_local,
    ):
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_sn_messaging_local()
        message_payload = increment_value.to_bytes(32, "big")
        with evm_error("INVALID_MESSAGE_TO_CONSUME"):
            l1_kakarot_messaging.consumeMessageFromL2(
                message_app_l2.address, message_payload
            )


@pytest.mark.slow
@pytest.mark.asyncio(scope="module")
class TestL1ToL2Messages:
    async def test_should_increment_counter_on_l2(self, message_app_l1, message_app_l2):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        increment_value = 1
        message_app_l1.increaseL2AppCounter(
            message_app_l2.address, value=increment_value
        )
        time.sleep(4)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_fail_unauthorized_message_sender(
        self, l1_kakarot_messaging, message_app_l1, message_app_l2
    ):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        await invoke(
            "kakarot",
            "set_l1_messaging_contract_address",
            0,
        )
        message_app_l1.increaseL2AppCounter(message_app_l2.address, value=1)
        time.sleep(4)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before
