# source: https://github.com/OpenZeppelin/cairo-contracts/tree/main/tests/signers.py

from starkware.starknet.business_logic.transaction.objects import (
    InternalTransaction,
    TransactionExecutionInfo,
)
from starkware.starknet.core.os.transaction_hash.transaction_hash import (
    TransactionHashPrefix,
    calculate_transaction_hash_common,
)
from starkware.starknet.definitions.general_config import StarknetChainId
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.services.api.gateway.transaction import InvokeFunction

from tests.utils.uint256 import int_to_uint256

class_hash = 0x1
TRANSACTION_VERSION = 1


def get_transaction_hash(prefix, account, calldata, nonce, max_fee, version, chain_id):
    """Compute the hash of a transaction."""
    return calculate_transaction_hash_common(
        tx_hash_prefix=prefix,
        version=version,
        contract_address=account,
        entry_point_selector=0,
        calldata=calldata,
        max_fee=max_fee,
        chain_id=chain_id,
        additional_data=[nonce],
    )


def from_call_to_call_array(calls):
    """Transform from Call to CallArray."""
    call_array = []
    calldata = []
    for _, call in enumerate(calls):
        assert len(call) == 3, "Invalid call parameters"
        entry = (
            call[0],
            get_selector_from_name(call[1]),
            len(calldata),
            len(call[2]),
        )
        call_array.append(entry)
        calldata.extend(call[2])
    return (call_array, calldata)


class MockEthSigner:
    def __init__(self, private_key):
        self.signer = private_key
        self.eth_address = int(self.signer.public_key.to_checksum_address(), 0)
        self.class_hash = class_hash

    async def send_transaction(
        self, account, to, selector_name, calldata, nonce=None, max_fee=0
    ):
        return await self.send_transactions(
            account, [(to, selector_name, calldata)], nonce, max_fee
        )

    async def send_transactions(
        self, account, calls, nonce=None, max_fee=0
    ) -> TransactionExecutionInfo:
        raw_invocation = get_raw_invoke(account, calls)
        state = raw_invocation.state

        if nonce is None:
            nonce = await state.state.get_nonce_at(account.contract_address)

        transaction_hash = get_transaction_hash(
            prefix=TransactionHashPrefix.INVOKE,
            account=account.contract_address,
            calldata=raw_invocation.calldata,
            version=TRANSACTION_VERSION,
            chain_id=StarknetChainId.TESTNET.value,
            nonce=nonce,
            max_fee=max_fee,
        )

        signature = self.sign(transaction_hash)

        external_tx = InvokeFunction(
            contract_address=account.contract_address,
            calldata=raw_invocation.calldata,
            entry_point_selector=None,
            signature=signature,
            max_fee=max_fee,
            version=TRANSACTION_VERSION,
            nonce=nonce,
        )

        tx = InternalTransaction.from_external(
            external_tx=external_tx, general_config=state.general_config
        )
        execution_info = await state.execute_tx(tx=tx)
        return execution_info

    def sign(self, transaction_hash):
        signature = self.signer.sign_msg_hash(
            (transaction_hash).to_bytes(32, byteorder="big")
        )
        sig_r = int_to_uint256(signature.r)
        sig_s = int_to_uint256(signature.s)
        return [signature.v, *sig_r, *sig_s]


def get_raw_invoke(sender, calls):
    """Return raw invoke, remove when test framework supports `invoke`."""
    call_array, calldata = from_call_to_call_array(calls)
    raw_invocation = sender.__execute__(call_array, calldata)
    return raw_invocation
