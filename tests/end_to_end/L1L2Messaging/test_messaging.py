import asyncio
import time

import pytest
import pytest_asyncio
from eth_utils.address import to_checksum_address

from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.l1 import deploy_on_l1, get_l1_addresses, get_l1_contract
from kakarot_scripts.utils.starknet import invoke
from tests.utils.errors import evm_error


@pytest.fixture(scope="session")
def l1_addresses():
    return get_l1_addresses()


@pytest.fixture(scope="session")
def starknet_core(l1_addresses):
    return get_l1_contract(
        "Starknet", "StarknetMessagingLocal", l1_addresses["StarknetCore"]
    )


@pytest.fixture(scope="session")
def l1_kakarot_messaging(l1_addresses):
    return get_l1_contract(
        "L1L2Messaging", "L1KakarotMessaging", l1_addresses["L1KakarotMessaging"]
    )


@pytest.fixture(scope="session")
def message_app_l1(kakarot, l1_addresses):
    return deploy_on_l1(
        "L1L2Messaging",
        "MessageAppL1",
        starknetMessaging=l1_addresses["StarknetCore"],
        l1KakarotMessaging=l1_addresses["L1KakarotMessaging"],
        kakarotAddress=kakarot.address,
    )


@pytest_asyncio.fixture(scope="session")
async def message_app_l2(message_app_l1):
    return await deploy(
        "L1L2Messaging",
        "MessageAppL2",
        l2KakarotMessaging_=to_checksum_address(
            get_evm_deployments()["L2KakarotMessaging"]["address"]
        ),
        l1ContractCounterPart_=message_app_l1.address,
    )


@pytest.fixture(scope="function")
def wait_for_messaging(starknet_core):

    async def _factory():
        event_filter_sn_messaging_local = (
            starknet_core.events.MessageHashesAddedFromL2.create_filter(
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
        wait_for_messaging,
    ):
        msg_counter_before = message_app_l1.receivedMessagesCounter()
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_messaging()
        message_payload = increment_value.to_bytes(32, "big")
        message_app_l1.consumeCounterIncrease(message_app_l2.address, message_payload)
        msg_counter_after = message_app_l1.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_fail_unauthorized_message_sender(
        self,
        message_app_l1,
        message_app_l2,
        l1_kakarot_messaging,
        wait_for_messaging,
    ):
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_messaging()
        message_payload = increment_value.to_bytes(32, "big")
        with evm_error("INVALID_MESSAGE_TO_CONSUME"):
            await l1_kakarot_messaging.consumeMessageFromL2(
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

    async def test_should_apply_alias_from_l1(self, message_app_l1, message_app_l2):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        increment_value = 1
        message_app_l1.increaseL2AppCounterFromCounterPartOnly(
            message_app_l2.address, value=increment_value
        )
        time.sleep(4)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_fail_unauthorized_message_sender(
        self, l1_kakarot_messaging, message_app_l1, message_app_l2
    ):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        await invoke("kakarot", "set_l1_messaging_contract_address", 0)
        message_app_l1.increaseL2AppCounter(message_app_l2.address, value=1)
        time.sleep(4)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before
        # teardown
        await invoke(
            "kakarot",
            "set_l1_messaging_contract_address",
            int(l1_kakarot_messaging.address, 16),
        )
