import pytest
from eth_utils import keccak

from tests.utils.helpers import ec_sign


@pytest.fixture(scope="module")
def commit():
    return keccak(b"Some unique commit data")


@pytest.fixture(autouse=True)
async def cleanup(sender_recorder):
    yield
    await sender_recorder.reset()


@pytest.mark.asyncio(scope="package")
@pytest.mark.EIP3074
class TestEIP3074:
    class TestEIP3074Integration:
        async def test_should_execute_authorized_call(
            self, gas_sponsor_invoker, sender_recorder, other, commit
        ):
            initial_sender = await sender_recorder.lastSender()
            assert int(initial_sender, 16) == 0
            signer_nonce = await other.starknet_contract.get_nonce()
            digest = await gas_sponsor_invoker.getDigest(commit, signer_nonce)
            v, r_, s_ = ec_sign(digest, other.private_key)

            calldata = sender_recorder.get_function_by_name(
                "recordSender"
            )()._encode_transaction_data()

            await gas_sponsor_invoker.sponsorCall(
                other.address, commit, v, r_, s_, sender_recorder.address, calldata
            )
            last_sender = await sender_recorder.lastSender()
            assert last_sender == other.address
