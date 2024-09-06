# %% Imports
import logging
from asyncio import run

from kakarot_scripts.constants import ETH_TOKEN_ADDRESS, NETWORK, RPC_CLIENT
from kakarot_scripts.utils.starknet import get_balance, get_declarations, invoke

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Withdraw all accounts
    contracts = [
        {
            "evm_address": "0xb7f8bc63bbcad18155201308c8f3540b07f84f5e",
            "starknet_address": "0x287321a33a66eb6b8e8ceb8bd8259e52fa39a419b38728dcb2425630377bbc4",
        },
        {
            "evm_address": "0x610178da211fef7d417bc0e6fed39f05609ad788",
            "starknet_address": "0x174a7051dc021598fd9c3d09071339e7c6d2ea990147933f441aa7c9438a900",
        },
        {
            "evm_address": "0x8a791620dd6260079bf849dc5567adc3f2fdc318",
            "starknet_address": "0x57a40e006025d496e59d3fff4e6fc26051b57b50b75ee4f6cb0393f5937adbe",
        },
        {
            "evm_address": "0x2279b7a0a67db372996a5fab50d91eaa73d2ebe6",
            "starknet_address": "0x7c312387195a5237661bfcdfb09c372df8a34bc33d02882785bcf574fb1ccb5",
        },
        {
            "evm_address": "0xa513e6e4b8f2a923d98304ec87f64353c4d5c853",
            "starknet_address": "0x317ec03f389b52d1dfd0264af0de39c8cd9732ff16603111839ee3d15b028c9",
        },
        {
            "evm_address": "0xcf7ed3acca5a467e9e704c703e8d87f634fb0fc9",
            "starknet_address": "0x21b76c798ab27abb833273b6421e5ef8d58ce8d882a5306f9aa3a7f9391032",
        },
        {
            "evm_address": "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512",
            "starknet_address": "0x74c4f2f012c90ebf5bf8baf30136805a4f47ba3641b45c99919d7f6e764abfc",
        },
        {
            "evm_address": "0x5fbdb2315678afecb367f032d93f642f64180aa3",
            "starknet_address": "0x54396c0bb2a0fee00c36a7dc043f4d8f73ef33cf6d06f3a94ba96e24248a99",
        },
        {
            "evm_address": "0x20eb005c0b9c906691f885eca5895338e15c36de",
            "starknet_address": "0x28b198562ad6725157c4661e768f86da48f7e9984cb1d5d7dc2e4d639dd02fb",
        },
        {
            "evm_address": "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
            "starknet_address": "0x48f1d0e5fe313a9de15b1f91ab45caf3c6ef53d9b1a5d7df1ecabc90b51d32",
        },
    ]

    balance_prev = await get_balance(NETWORK["account_address"])
    logger.info(f"ℹ️  Current deployer balance {balance_prev / 1e18} ETH")
    for contract in contracts:
        balance = await get_balance(contract["starknet_address"])
        if balance == 0:
            logger.info(
                f"ℹ️  No balance to withdraw from EVM contract {contract['evm_address']}"
            )
            continue

        logger.info(
            f"ℹ️  Withdrawing {balance / 1e18} ETH from EVM contract {contract['evm_address']}"
        )
        current_class = await RPC_CLIENT.get_class_hash_at(contract["starknet_address"])
        await invoke(
            "kakarot",
            "upgrade_account",
            int(contract["evm_address"], 16),
            get_declarations()["BalanceSender"],
        )
        await invoke(
            "BalanceSender",
            "send_balance",
            ETH_TOKEN_ADDRESS,
            int(NETWORK["account_address"], 16),
            address=int(contract["starknet_address"], 16),
        )
        await invoke(
            "kakarot",
            "upgrade_account",
            int(contract["evm_address"], 16),
            current_class,
        )
    balance = await get_balance(NETWORK["account_address"])
    logger.info(
        f"ℹ️  Current deployer balance {balance / 1e18} ETH: {(balance - balance_prev) / 1e18} ETH recovered"
    )


# %% Run
if __name__ == "__main__":
    run(main())
