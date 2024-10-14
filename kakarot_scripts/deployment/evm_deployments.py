# %% Imports
import logging

from eth_utils.address import to_checksum_address
from uvloop import run

from kakarot_scripts.constants import (
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    NETWORK,
    RPC_CLIENT,
    STRK_TOKEN_ADDRESS,
    NetworkType,
)
from kakarot_scripts.utils.kakarot import deploy as deploy_evm
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import call, execute_calls
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import invoke

logger = logging.getLogger(__name__)


# %%
async def deploy_evm_contracts():
    # %% Deployments
    logger.info(f"ℹ️  Using account {EVM_ADDRESS} as deployer")

    await deploy_and_fund_evm_address(
        EVM_ADDRESS, amount=100 if NETWORK["type"] is NetworkType.DEV else 0.01
    )

    starknet_deployments = get_starknet_deployments()
    evm_deployments = get_evm_deployments()

    # %% Tokens
    for (
        contract_app,
        contract_name,
        deployed_name,
        cairo_precompile,
        *deployment_args,
    ) in [
        ("WETH", "WETH9", "WETH9", False),
        (
            "CairoPrecompiles",
            "DualVmToken",
            "KakarotETH",
            True,
            starknet_deployments["kakarot"],
            ETH_TOKEN_ADDRESS,
        ),
        (
            "CairoPrecompiles",
            "DualVmToken",
            "KakarotSTRK",
            True,
            starknet_deployments["kakarot"],
            STRK_TOKEN_ADDRESS,
        ),
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
        if cairo_precompile:
            await invoke(
                "kakarot",
                "set_authorized_cairo_precompile_caller",
                int(token.address, 16),
                1,
            )

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

    await deploy_evm_contracts()
    await execute_calls()


def main_sync():
    run(main())


if __name__ == "__main__":
    main_sync()
