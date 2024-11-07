import logging

from async_lru import alru_cache
from starknet_py.net.account.account import Account

from kakarot_scripts.constants import NETWORK
from kakarot_scripts.utils.starknet import (
    deploy_starknet_account,
    get_eth_contract,
    get_starknet_account,
    invoke,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


class RelayerPool:
    _cached_relayers = None

    def __init__(self, accounts):
        self.relayer_accounts = accounts
        self.index = 0

    @classmethod
    @alru_cache
    async def create(cls, n):
        logger.info(f"ℹ️  Creating {n} relayer accounts")
        accounts = []
        for i in range(n):
            receipt = await deploy_starknet_account(
                salt=i + int(NETWORK["account_address"], 16)
            )
            account = await get_starknet_account(address=receipt["address"])
            accounts.append(account)
        logger.info(f"✅ Created {n} relayer accounts")
        return cls(accounts)

    def __next__(self) -> Account:
        relayer = self.relayer_accounts[self.index]
        self.index = (self.index + 1) % len(self.relayer_accounts)
        return relayer

    @classmethod
    @alru_cache
    async def default(cls):
        return await cls.create(NETWORK.get("relayers", 20))

    @classmethod
    @alru_cache
    async def get(cls, salt: int):
        if cls._cached_relayers is None:
            cls._cached_relayers = await cls.default()

        return cls._cached_relayers.relayer_accounts[
            salt % len(cls._cached_relayers.relayer_accounts)
        ]

    @classmethod
    async def withdraw_all(cls, to: int = int(NETWORK["account_address"], 16)):
        relayers = await cls.default()
        eth_contract = await get_eth_contract()
        for relayer in relayers.relayer_accounts:
            balance = (
                await eth_contract.functions["balanceOf"].call(relayer.address)
            ).balance
            if balance > 0:
                await invoke(
                    "ERC20",
                    "transfer",
                    to,
                    balance,
                    account=relayer,
                    address=eth_contract.address,
                )
