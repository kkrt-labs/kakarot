import logging

from eth_abi.exceptions import InsufficientDataBytes
from web3.exceptions import ContractLogicError

from kakarot_scripts.constants import NETWORK, RPC_CLIENT, NetworkType
from kakarot_scripts.utils.kakarot import deploy as deploy_evm
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.l1 import (
    deploy_on_l1,
    dump_l1_addresses,
    get_l1_addresses,
    get_l1_contract,
)
from kakarot_scripts.utils.starknet import call
from kakarot_scripts.utils.starknet import get_deployments as get_starknet_deployments
from kakarot_scripts.utils.starknet import invoke

logger = logging.getLogger(__name__)


async def deploy_l1_contracts():
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


async def deploy_messaging_contracts():
    # %% Messaging
    evm_deployments = get_evm_deployments()
    l1_kakarot_messaging_address = get_l1_addresses()["L1KakarotMessaging"]
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
    if l1_messaging_contract_address != int(l1_kakarot_messaging_address, 16):
        await invoke(
            "kakarot",
            "set_l1_messaging_contract_address",
            int(l1_kakarot_messaging_address, 16),
        )

    dump_evm_deployments(evm_deployments)


if __name__ == "__main__":
    from uvloop import run

    async def main():
        try:
            await RPC_CLIENT.get_class_hash_at(get_starknet_deployments()["kakarot"])
        except Exception:
            logger.error("❌ Kakarot is not deployed, exiting...")
            return
        await deploy_l1_contracts()
        await deploy_messaging_contracts()

    run(main())
