# %% Imports
import logging

from eth_utils.address import to_checksum_address
from uvloop import run

from kakarot_scripts.constants import EVM_ADDRESS, NETWORK, RPC_CLIENT, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_evm
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import call, execute_calls
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import (
    get_starknet_account,
    invoke,
    register_lazy_account,
    remove_lazy_account,
)

logger = logging.getLogger(__name__)


# %%
async def deploy_evm_contracts():
    # %% Deployments
    logger.info(f"ℹ️  Using account {EVM_ADDRESS} as deployer")

    await deploy_and_fund_evm_address(
        EVM_ADDRESS, amount=100 if NETWORK["type"] is NetworkType.DEV else 0.01
    )

    evm_deployments = get_evm_deployments()

    # %% Pure EVM Tokens
    for (
        contract_app,
        contract_name,
        deployed_name,
        *deployment_args,
    ) in [
        ("WETH", "WETH9", "WETH9"),
    ]:
        deployment = evm_deployments.get(deployed_name)
        if deployment is not None:
            token_starknet_address = (
                await call("kakarot", "get_starknet_address", deployment["address"])
            ).starknet_address
            if deployment["starknet_address"] == token_starknet_address:
                logger.info(f"✅ {deployed_name} already deployed, skipping")
                continue

        token = await deploy_evm(contract_app, contract_name, *deployment_args)
        evm_deployments[deployed_name] = {
            "address": int(token.address, 16),
            "starknet_address": token.starknet_address,
        }

    # %% Coinbase
    coinbase = (await call("kakarot", "get_coinbase")).coinbase
    if evm_deployments.get("Coinbase", {}).get("address") != coinbase:
        contract = await deploy_evm(
            "Kakarot",
            "Coinbase",
            to_checksum_address(f'{evm_deployments["KakarotETH"]["address"]:040x}'),
        )
        evm_deployments["Coinbase"] = {
            "address": int(contract.address, 16),
            "starknet_address": contract.starknet_address,
        }
        await invoke("kakarot", "set_coinbase", int(contract.address, 16))

    # %% Tear down
    dump_evm_deployments(evm_deployments)


# %% Run
async def main():
    try:
        await RPC_CLIENT.get_class_hash_at(get_starknet_deployments()["kakarot"])
    except Exception:
        logger.error("❌ Kakarot is not deployed, exiting...")
        return

    if not EVM_ADDRESS:
        logger.warn("⚠️  No EVM address provided, skipping EVM deployments")
        return

    account = await get_starknet_account()
    register_lazy_account(account.address)
    await deploy_evm_contracts()
    await execute_calls()
    remove_lazy_account(account.address)


def main_sync():
    run(main())


if __name__ == "__main__":
    main_sync()
