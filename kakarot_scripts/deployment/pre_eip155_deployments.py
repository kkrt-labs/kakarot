from asyncio.log import logger

from kakarot_scripts.constants import PRE_EIP155_TX, RPC_CLIENT
from kakarot_scripts.utils.kakarot import dump_deployments as dump_evm_deployments
from kakarot_scripts.utils.kakarot import get_deployments
from kakarot_scripts.utils.kakarot import get_deployments as get_evm_deployments
from kakarot_scripts.utils.kakarot import (
    get_starknet_address,
    send_pre_eip155_transaction,
    whitelist_pre_eip155_tx,
)
from kakarot_scripts.utils.starknet import (
    execute_calls,
    get_starknet_account,
    register_lazy_account,
    remove_lazy_account,
)


async def whitelist_pre_eip155_contracts():
    for contract_name in PRE_EIP155_TX.keys():
        await whitelist_pre_eip155_tx(contract_name)


async def deploy_pre_eip155_contracts():
    evm_deployments = get_evm_deployments()

    for contract_name in PRE_EIP155_TX.keys():
        await send_pre_eip155_transaction(contract_name, max_fee=int(0.2e18))
        deployed_address = int(PRE_EIP155_TX[contract_name]["address"], 16)
        evm_deployments[contract_name] = {
            "address": deployed_address,
            "starknet_address": await get_starknet_address(deployed_address),
        }

    dump_evm_deployments(evm_deployments)


if __name__ == "__main__":
    from uvloop import run

    async def main():

        try:
            await RPC_CLIENT.get_class_hash_at(get_deployments()["kakarot"])
        except Exception:
            logger.error("❌ Kakarot is not deployed, exiting...")
            return

        # lazy whitelisting of multiple contracts
        account = await get_starknet_account()
        register_lazy_account(account.address)
        await whitelist_pre_eip155_contracts()
        await execute_calls()
        remove_lazy_account(account.address)

        await deploy_pre_eip155_contracts()

    run(main())
