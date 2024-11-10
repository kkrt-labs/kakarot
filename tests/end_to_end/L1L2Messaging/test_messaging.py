import asyncio

import pytest
import pytest_asyncio
from eth_utils.address import to_checksum_address
from starknet_py.net.client_errors import ClientError
from starknet_py.net.client_models import L1HandlerTransaction

from kakarot_scripts.constants import NETWORK, RPC_CLIENT
from kakarot_scripts.utils.kakarot import deploy
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.l1 import deploy_on_l1, get_l1_addresses, get_l1_contract
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
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
def wait_for_l1_messaging(starknet_core):

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


@pytest.fixture(scope="function")
def wait_for_l2_messaging():
    async def _factory(block_number):
        l1_handlers = []
        i = 0
        # L1 block time is 12s and Starknet block time is 30s
        # 2 minutes should be enough to trigger the L1 handler
        while i < 2 * 60:
            try:
                # Reach the tip of the chain
                block = await RPC_CLIENT.get_block(block_number=block_number + i)
            except ClientError:
                # If the block is not found, it means we reached the pending block
                block = await RPC_CLIENT.get_block(block_number="pending")

            l1_handlers += [
                transaction
                for transaction in block.transactions
                if isinstance(transaction, L1HandlerTransaction)
                and transaction.contract_address
                == get_starknet_deployments()["kakarot"]
            ]
            if l1_handlers:
                return l1_handlers
            i += 1
            await asyncio.sleep(1)

        raise Exception("L1 handlers not found in 2 minutes")

    return _factory


@pytest.mark.slow
@pytest.mark.asyncio(scope="module")
@pytest.mark.skipif(
    NETWORK["name"] != "katana",
    reason="L2 to L1 messaging on sepolia requires waiting for Starknet to prove blocks",
)
class TestL2ToL1Messages:
    async def test_should_increment_counter_on_l1(
        self,
        message_app_l1,
        message_app_l2,
        wait_for_l1_messaging,
    ):
        msg_counter_before = message_app_l1.receivedMessagesCounter()
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_l1_messaging()
        message_payload = increment_value.to_bytes(32, "big")
        message_app_l1.consumeCounterIncrease(message_app_l2.address, message_payload)
        msg_counter_after = message_app_l1.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_fail_unauthorized_message_sender(
        self,
        message_app_l1,
        message_app_l2,
        l1_kakarot_messaging,
        wait_for_l1_messaging,
    ):
        increment_value = 8
        await message_app_l2.increaseL1AppCounter(
            message_app_l1.address, increment_value
        )
        await wait_for_l1_messaging()
        message_payload = increment_value.to_bytes(32, "big")
        with evm_error("INVALID_MESSAGE_TO_CONSUME"):
            await l1_kakarot_messaging.consumeMessageFromL2(
                message_app_l2.address, message_payload
            )


@pytest.mark.slow
@pytest.mark.asyncio(scope="module")
class TestL1ToL2Messages:
    async def test_should_increment_counter_on_l2(
        self, message_app_l1, message_app_l2, wait_for_l2_messaging
    ):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        increment_value = 1
        current_l2_block = await RPC_CLIENT.get_block_number()
        message_app_l1.increaseL2AppCounter(
            message_app_l2.address, value=increment_value
        )
        await wait_for_l2_messaging(current_l2_block)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value

    async def test_should_apply_alias_from_l1(
        self, message_app_l1, message_app_l2, wait_for_l2_messaging
    ):
        msg_counter_before = await message_app_l2.receivedMessagesCounter()
        increment_value = 1
        current_l2_block = await RPC_CLIENT.get_block_number()
        message_app_l1.increaseL2AppCounterFromCounterPartOnly(
            message_app_l2.address, value=increment_value
        )
        await wait_for_l2_messaging(current_l2_block)
        msg_counter_after = await message_app_l2.receivedMessagesCounter()
        assert msg_counter_after == msg_counter_before + increment_value
