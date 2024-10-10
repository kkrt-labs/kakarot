import logging


from kakarot_scripts.constants import ETH_TOKEN_ADDRESS, EVM_ADDRESS, NETWORK, RPC_CLIENT, STRK_TOKEN_ADDRESS, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_evm, get_deployments as get_evm_deployments
from kakarot_scripts.utils.kakarot import deploy_and_fund_evm_address
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.l1 import deploy_on_l1, dump_l1_addresses, get_l1_addresses, get_l1_contract
from kakarot_scripts.utils.starknet import call, execute_calls, get_balance, invoke
from web3.exceptions import ContractLogicError
from eth_utils.address import to_checksum_address
from eth_abi.exceptions import InsufficientDataBytes

logger = logging.getLogger(__name__)


async def deploy_evm_contracts():
    # %% L1
    starknet_deployments = get_starknet_deployments()
    l1_addresses = get_l1_addresses()

    l1_kakarot_messaging = get_l1_contract(
        "L1L2Messaging",
        "L1KakarotMessaging",
        address=l1_addresses.get("L1KakarotMessaging"),
    )
    l1_kakarot_messaging_registered_address = None
    try:
        l1_kakarot_messaging_registered_address = l1_kakarot_messaging.kakarotAddress()
    except (ContractLogicError, InsufficientDataBytes):
        pass

    if l1_kakarot_messaging_registered_address != starknet_deployments["kakarot"]:
        if NETWORK["type"] == NetworkType.DEV:
            starknet_core = deploy_on_l1("Starknet", "StarknetMessagingLocal")
            l1_addresses.update({"StarknetCore": starknet_core.address})
        else:
            if "StarknetCore" not in l1_addresses:
                raise ValueError("StarknetCore missing in L1 addresses")

        l1_kakarot_messaging = deploy_on_l1(
            "L1L2Messaging",
            "L1KakarotMessaging",
            l1_addresses["StarknetCore"],
            starknet_deployments["kakarot"],
        )
        l1_addresses.update({"L1KakarotMessaging": l1_kakarot_messaging.address})

    dump_l1_addresses(l1_addresses)

    if not EVM_ADDRESS:
        logger.info("ℹ️  No EVM address provided, skipping EVM deployments")
        return

    logger.info(f"ℹ️  Using account {EVM_ADDRESS} as deployer")

    await deploy_and_fund_evm_address(
        EVM_ADDRESS, amount=100 if NETWORK["type"] is NetworkType.DEV else 0.01
    )

    starknet_deployments = get_starknet_deployments()
    evm_deployments = get_evm_deployments()

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

   # %% Messaging
    deployment = evm_deployments.get("L2KakarotMessaging")
    starknet_address = None
    if deployment is not None:
        starknet_address = (
            await call("kakarot", "get_starknet_address", deployment["address"])
        ).starknet_address

    if deployment is None or deployment["starknet_address"] != starknet_address:
        l2_kakarot_messaging = await deploy_evm("L1L2Messaging", "L2KakarotMessaging")
        await invoke(
            "kakarot",
            "set_authorized_cairo_precompile_caller",
            int(l2_kakarot_messaging.address, 16),
            1,
        )
        evm_deployments["L2KakarotMessaging"] = {
            "address": int(l2_kakarot_messaging.address, 16),
            "starknet_address": l2_kakarot_messaging.starknet_address,
        }

    l1_messaging_contract_address = (
        await call("kakarot", "get_l1_messaging_contract_address")
    ).l1_messaging_contract_address
    if l1_messaging_contract_address != int(l1_kakarot_messaging.address, 16):
        await invoke(
            "kakarot",
            "set_l1_messaging_contract_address",
            int(l1_kakarot_messaging.address, 16),
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
    await execute_calls()
    dump_evm_deployments(evm_deployments)

if __name__ == "__main__":
    from uvloop import run

    async def main():
        try:
            await RPC_CLIENT.get_class_hash_at(get_starknet_deployments()["kakarot"])
        except Exception:
            logger.error("❌ Kakarot is not deployed, exiting...")
            return
        await deploy_evm_contracts()

    run(main())
