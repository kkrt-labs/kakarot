import json
import logging
from pathlib import Path
from typing import Union

from starknet_py.contract import Contract
from starknet_py.net.account.account_client import AccountClient

logger = logging.getLogger()
MAX_FEE = int(1e16)
BUILD_PATH = Path("build")

# Declare and Deploy a Contract
async def declare_and_deploy_contracts(
    client: AccountClient,
    contracts: list[str],
    calldata: list[list[Union[str, int]]],
) -> (list[Contract]):

    deployed_contract = []

    for contract, _calldata in zip(contracts, calldata):
        compiled_contract = (BUILD_PATH / f"{contract}.json").read_text()
        json.loads((BUILD_PATH / f"{contract}_abi.json").read_text())
        declare_result = await Contract.declare(
            account=client, compiled_contract=compiled_contract, max_fee=MAX_FEE
        )
        await declare_result.wait_for_acceptance()

        deploy_result = await declare_result.deploy(
            max_fee=MAX_FEE, constructor_args=_calldata
        )
        await deploy_result.wait_for_acceptance()
        deployed_contract.append(deploy_result.deployed_contract)
        logger.info(f"✅ {contract} address: {deploy_result.deployed_contract.address}")

    return deployed_contract


# Declare a Contract
async def declare_contract(client: AccountClient, contract: str) -> int:
    compiled_contract = (BUILD_PATH / f"{contract}.json").read_text()
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=MAX_FEE
    )
    await declare_result.wait_for_acceptance()
    logger.info(f"✅ {contract} class hash: {declare_result.class_hash:x}")

    return declare_result.class_hash
