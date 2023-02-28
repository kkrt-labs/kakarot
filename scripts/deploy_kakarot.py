import logging
from asyncio import run
from math import ceil, log

from scripts.constants import CHAIN_ID, EVM_ADDRESS, GATEWAY_CLIENT
from scripts.utils import (
    declare,
    deploy,
    deploy_and_fund_evm_address,
    dump_declarations,
    dump_deployments,
    get_account,
    get_declarations,
    get_eth_contract,
    invoke,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


async def main():
    logger.info(
        f"ℹ️ Connected to CHAIN_ID {CHAIN_ID.value.to_bytes(ceil(log(CHAIN_ID.value, 256)), 'big')} "
        f"with GATEWAY {GATEWAY_CLIENT.net}"
    )

    class_hash = {
        contract_name: await declare(contract_name)
        for contract_name in [
            "contract_account",
            "externally_owned_account",
            "proxy_account",
            "kakarot",
            "blockhash_registry",
        ]
    }
    dump_declarations(class_hash)
    class_hash = get_declarations()

    eth = await get_eth_contract()
    account = get_account()

    deployments = {}
    deployments["kakarot"] = await deploy(
        "kakarot",
        account.address,  # owner
        eth.address,  # native_token_address_
        class_hash["contract_account"],  # contract_account_class_hash_
        class_hash["externally_owned_account"],  # externally_owned_account_class_hash
        class_hash["proxy_account"],  # account_proxy_class_hash
    )
    deployments["blockhash_registry"] = await deploy(
        "blockhash_registry",
        deployments["kakarot"]["address"],
    )
    dump_deployments(deployments)

    logging.info("⏳ Configuring Contracts...")
    await invoke(
        "kakarot",
        "set_blockhash_registry",
        deployments["blockhash_registry"]["address"],
    )
    logging.info("✅ Configuration Complete")

    if EVM_ADDRESS:
        logging.info(f"ℹ️ Found default EVM address {EVM_ADDRESS} to deploy an EOA for")
        await deploy_and_fund_evm_address(EVM_ADDRESS, 0.1)


if __name__ == "__main__":
    run(main())
