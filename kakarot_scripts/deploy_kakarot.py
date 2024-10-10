# %% Imports
import logging

from eth_abi.exceptions import InsufficientDataBytes
from eth_utils.address import to_checksum_address
from uvloop import run
from web3.exceptions import ContractLogicError

from kakarot_scripts.constants import (
    ARACHNID_PROXY_DEPLOYER,
    ARACHNID_PROXY_SIGNED_TX,
    BLOCK_GAS_LIMIT,
    COINBASE,
    CREATEX_DEPLOYER,
    CREATEX_SIGNED_TX,
    DECLARED_CONTRACTS,
    DEFAULT_GAS_PRICE,
    ETH_TOKEN_ADDRESS,
    EVM_ADDRESS,
    MULTICALL3_DEPLOYER,
    MULTICALL3_SIGNED_TX,
    NETWORK,
    RPC_CLIENT,
    STRK_TOKEN_ADDRESS,
    NetworkType,
)
from kakarot_scripts.utils.kakarot import deploy as deploy_evm
from kakarot_scripts.utils.kakarot import (
    deploy_and_fund_evm_address,
    deploy_with_presigned_tx,
)
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.l1 import (
    deploy_on_l1,
    dump_l1_addresses,
    get_l1_addresses,
    get_l1_contract,
)
from kakarot_scripts.utils.starknet import call, declare
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import (
    dump_declarations,
    dump_deployments,
    execute_calls,
    get_balance,
    get_declarations,
)
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import (
    get_starknet_account,
    invoke,
    register_lazy_account,
    remove_lazy_account,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# %% Main
async def main():
    # %% Declarations
    account = await get_starknet_account()
    register_lazy_account(account.address)
    logger.info(f"ℹ️  Using account 0x{account.address:064x} as deployer")
    balance_pref = await get_balance(account.address)

    class_hash = {contract: await declare(contract) for contract in DECLARED_CONTRACTS}
    dump_declarations(class_hash)

    # %% Starknet Deployments
    class_hash = get_declarations()
    starknet_deployments = get_starknet_deployments()

    if NETWORK["type"] is not NetworkType.PROD:
        starknet_deployments["EVM"] = await deploy_starknet(
            "EVM",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            BLOCK_GAS_LIMIT,
        )
        await invoke(
            "EVM",
            "set_coinbase",
            COINBASE,
            address=starknet_deployments["EVM"],
        )
        starknet_deployments["Counter"] = await deploy_starknet("Counter")
        starknet_deployments["MockPragmaOracle"] = await deploy_starknet(
            "MockPragmaOracle"
        )
        starknet_deployments["UniversalLibraryCaller"] = await deploy_starknet(
            "UniversalLibraryCaller"
        )
        starknet_deployments["BenchmarkCairoCalls"] = await deploy_starknet(
            "BenchmarkCairoCalls"
        )

    # Deploy or upgrade Kakarot
    if starknet_deployments.get("kakarot") and NETWORK["type"] is not NetworkType.DEV:
        logger.info("ℹ️  Kakarot already deployed, checking version.")
        deployed_class_hash = await RPC_CLIENT.get_class_hash_at(
            starknet_deployments["kakarot"]
        )
        if deployed_class_hash != class_hash["kakarot"]:
            await invoke("kakarot", "upgrade", class_hash["kakarot"])
            await invoke(
                "kakarot",
                "set_account_contract_class_hash",
                class_hash["account_contract"],
            )
            await invoke(
                "kakarot",
                "set_cairo1_helpers_class_hash",
                class_hash["Cairo1Helpers"],
            )
        else:
            logger.info("✅ Kakarot already up to date.")
    else:
        starknet_deployments["kakarot"] = await deploy_starknet(
            "kakarot",
            account.address,  # owner
            ETH_TOKEN_ADDRESS,  # native_token_address_
            class_hash["account_contract"],  # account_contract_class_hash_
            class_hash["uninitialized_account"],  # uninitialized_account_class_hash_
            class_hash["Cairo1Helpers"],
            BLOCK_GAS_LIMIT,
        )
        await invoke(
            "kakarot",
            "set_base_fee",
            DEFAULT_GAS_PRICE,
            address=starknet_deployments["kakarot"],
        )

    dump_deployments(starknet_deployments)

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

    # %% Pre-EIP155 deployments, done only once and don't need an account
    # Kakarot needs to be deployed for the remaining calls to be executed
    await execute_calls()
    remove_lazy_account(account.address)
    await deploy_with_presigned_tx(
        MULTICALL3_DEPLOYER,
        MULTICALL3_SIGNED_TX,
        name="Multicall3",
        max_fee=int(0.1e18),
    )
    await deploy_with_presigned_tx(
        ARACHNID_PROXY_DEPLOYER,
        ARACHNID_PROXY_SIGNED_TX,
        name="Arachnid Proxy",
        max_fee=int(0.1e18),
    )
    await deploy_with_presigned_tx(
        CREATEX_DEPLOYER,
        CREATEX_SIGNED_TX,
        amount=0.3,
        name="CreateX",
        max_fee=int(0.2e18),
    )
    register_lazy_account(account.address)

    # %% EVM Deployments
    if not EVM_ADDRESS:
        logger.info("ℹ️  No EVM address provided, skipping EVM deployments")
        return

    logger.info(f"ℹ️  Using account {EVM_ADDRESS} as deployer")

    await deploy_and_fund_evm_address(
        EVM_ADDRESS, amount=100 if NETWORK["type"] is NetworkType.DEV else 0.01
    )

    starknet_deployments = get_starknet_deployments()
    evm_deployments = get_evm_deployments()

    # %% Tokens deployments
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
    balance_after = await get_balance(account.address)
    logger.info(
        f"ℹ💰  Deployer balance changed from {balance_pref / 1e18} to {balance_after / 1e18} ETH"
    )

    coinbase = (await call("kakarot", "get_coinbase")).coinbase
    if coinbase == 0:
        logger.error("❌ Coinbase is set to 0, all transaction fees will be lost")
    else:
        logger.info(f"✅ Coinbase set to: 0x{coinbase:040x}")


# %% Run
def main_sync():
    run(main())


if __name__ == "__main__":
    main_sync()
