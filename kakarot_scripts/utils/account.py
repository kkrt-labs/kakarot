import logging
from abc import ABC, abstractmethod
from typing import Optional

from eth_account import Account as EvmAccount
from eth_account._utils.typed_transactions import TypedTransaction
from eth_account.datastructures import SignedTransaction
from starknet_py.net.account.account import Account as InnerAccount
from starknet_py.net.client_models import Call
from starknet_py.net.models.transaction import InvokeV1

from tests.utils.helpers import rlp_encode_signed_data
from tests.utils.uint256 import int_to_uint256

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class Account(ABC):
    def __init__(self, account: InnerAccount):
        self.account = account

    # If the attribute is not found in the EthAccount class,
    # search for it in the Account class
    def __getattr__(self, name):
        return self.account.__getattribute__(name)

    async def sign_transaction(self, evm_tx: TypedTransaction) -> SignedTransaction:
        """
        Sign the transaction.
        """
        return EvmAccount.sign_transaction(
            evm_tx.as_dict(),
            hex(self.account.signer.private_key),
        )

    @abstractmethod
    async def send_transaction(self, tx_hash: str) -> str:
        """
        Send the transaction.
        """


# Wrapper around the starknetpy Account to provide helper methods on a ethereum rpc network
class EthAccount(Account):
    async def send_transaction(self, evm_tx: TypedTransaction) -> str:
        signed_transaction = self.sign_transaction(evm_tx)
        return self.account.client.eth.send_raw_transaction(
            signed_transaction.rawTransaction
        )


# Wrapper around the starknetpy Account to provide helper methods on a Starknet rpc network
class StarknetAccount(Account):
    # If the attribute is not found in the StarknetAccount class,
    # search for it in the Account class
    def __getattr__(self, name):
        return self.account.__getattribute__(name)

    async def send_transaction(
        self, evm_tx: TypedTransaction, max_fee: Optional[int] = None
    ) -> str:
        signed_transaction = self.sign_transaction(evm_tx)
        encoded_unsigned_tx = rlp_encode_signed_data(evm_tx.as_dict())
        prepared_invoke = await self.account._prepare_invoke(
            calls=[
                Call(
                    to_addr=0xDEAD,  # unused in current EOA implementation
                    selector=0xDEAD,  # unused in current EOA implementation
                    calldata=encoded_unsigned_tx,
                )
            ],
            max_fee=int(5e17) if max_fee is None else max_fee,
        )
        # We need to reconstruct the prepared_invoke with the new signature
        # And Invoke.signature is Frozen
        prepared_invoke = InvokeV1(
            version=prepared_invoke.version,
            max_fee=prepared_invoke.max_fee,
            signature=[
                *int_to_uint256(signed_transaction.r),
                *int_to_uint256(signed_transaction.s),
                signed_transaction.v,
            ],
            nonce=prepared_invoke.nonce,
            sender_address=prepared_invoke.sender_address,
            calldata=prepared_invoke.calldata,
        )
        return (
            await self.account.client.send_transaction(prepared_invoke)
        ).transaction_hash
