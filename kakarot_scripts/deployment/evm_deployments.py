import logging

from kakarot_scripts.constants import EVM_ADDRESS, NETWORK, RPC_CLIENT, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_evm
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.starknet import call, invoke

logger = logging.getLogger(__name__)


async def deploy_evm_contracts():
    if not EVM_ADDRESS:
        logger.info("ℹ️  No EVM address provided, skipping EVM deployments")
        return

    logger.info(f"ℹ️  Using account {EVM_ADDRESS} as deployer")

    await deploy_and_fund_evm_address(
        EVM_ADDRESS, amount=100 if NETWORK["type"] is NetworkType.DEV else 0.01
    )

    evm_deployments = get_evm_deployments()

    coinbase = (await call("kakarot", "get_coinbase")).coinbase
    if evm_deployments.get("Bridge", {}).get("address") != coinbase:
        bridge = await deploy_evm("CairoPrecompiles", "EthStarknetBridge")
        evm_deployments["Bridge"] = {
            "address": int(bridge.address, 16),
            "starknet_address": bridge.starknet_address,
        }
        await invoke(
            "kakarot",
            "set_authorized_cairo_precompile_caller",
            int(bridge.address, 16),
            1,
        )
        await invoke("kakarot", "set_coinbase", int(bridge.address, 16))

    coinbase = (await call("kakarot", "get_coinbase")).coinbase
    if coinbase == 0:
        logger.error("❌ Coinbase is set to 0, all transaction fees will be lost")
    else:
        logger.info(f"✅ Coinbase set to: 0x{coinbase:040x}")

    weth_starknet_address = (
        await call(
            "kakarot",
            "get_starknet_address",
            evm_deployments.get("WETH", {}).get("address", 0),
        )
    ).starknet_address
    if evm_deployments.get("WETH", {}).get("starknet_address") != weth_starknet_address:
        weth = await deploy_evm("WETH", "WETH9")
        evm_deployments["WETH"] = {
            "address": int(weth.address, 16),
            "starknet_address": weth.starknet_address,
        }

    dump_evm_deployments(evm_deployments)


if __name__ == "__main__":
    from uvloop import run

    async def main():
        try:
            await RPC_CLIENT.get_class_hash_at(get_evm_deployments()["kakarot"])
        except Exception:
            logger.error("❌ Kakarot is not deployed, exiting...")
            return
        await deploy_evm_contracts()

    run(main())
