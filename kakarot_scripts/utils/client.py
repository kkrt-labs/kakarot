import asyncio
import functools
import logging
from abc import ABC, abstractmethod

from starknet_py.net.client_models import TransactionReceipt
from starknet_py.net.full_node_client import FullNodeClient
from web3 import Web3
from web3.types import TxReceipt

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class TransactionStatus:
    SUCCESS = "✅"
    FAILED = "❌"


Hash = str


class Client(ABC):
    @abstractmethod
    async def wait_for_tx(
        self, tx_hash: str, interval: float = 2, retries: int = 100
    ) -> TransactionStatus:
        """
        Wait for a transaction to be mined and return the receipt.
        """

    @abstractmethod
    async def get_transaction_receipt(self, tx_hash: str) -> dict:
        """
        Get the transaction receipt.
        """


class StarknetClient(Client):
    def __init__(self, url: str):
        self.client = FullNodeClient(node_url=url)

    # If the attribute is not found in the StarknetClient class,
    # search for it in the FullNodeClient class
    def __getattr__(self, name):
        return self.client.__getattribute__(name)

    @functools.wraps(FullNodeClient.wait_for_tx)
    async def wait_for_tx(
        self, tx_hash: str, interval: float = 2, retries: int = 100
    ) -> TransactionStatus:
        """
        Wait for a transaction to be mined and return the receipt.
        """
        try:
            await self.client.wait_for_tx(
                tx_hash, check_interval=interval, retries=retries
            )
            return TransactionStatus.SUCCESS
        except Exception as e:
            logger.error(f"Error while waiting for transaction {tx_hash}: {e}")
            return TransactionStatus.FAILED

    @functools.wraps(FullNodeClient.get_transaction_receipt)
    async def get_transaction_receipt(self, tx_hash: str) -> TransactionReceipt:
        """
        Get the transaction receipt.
        """
        return await self.client.get_transaction_receipt(tx_hash)


class EthereumClient(Client):
    def __init__(self, url: str):
        self.client = Web3(Web3.HTTPProvider(url))

    async def wait_for_tx(
        self, tx_hash: str, interval: float = 2, retries: int = 100
    ) -> TransactionStatus:
        """
        Wait for a transaction to be mined and return the receipt.
        """
        while True:
            retries -= 1
            try:
                _ = self.client.eth.get_transaction(tx_hash)
            except Exception as e:
                if retries == 0:
                    logger.error(f"Error while waiting for transaction {tx_hash}: {e}")
                    return TransactionStatus.FAILED
                await asyncio.sleep(interval)
                continue

            return TransactionStatus.SUCCESS

    async def get_transaction_receipt(self, tx_hash: str) -> TxReceipt:
        """
        Get the transaction receipt.
        """
        return self.client.eth.get_transaction_receipt(tx_hash)
