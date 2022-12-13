from starknet_py.net.account.account_client import AccountClient
from starknet_py.contract import Contract
import logging

#Declare and Deploy a Contract
async def declare_and_deploy_contract(client: AccountClient,compiled_contract: str, calldata) -> (str):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=int(1e16)
    )
    await declare_result.wait_for_acceptance()

    deploy_result = await declare_result.deploy(max_fee=int(1e16), constructor_args=calldata)
    await deploy_result.wait_for_acceptance()
    contract = deploy_result.deployed_contract
    return hex(contract.address)

#Declare a Contract
async def declare_contract(client: AccountClient,compiled_contract: str) -> (int):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=int(1e16)
    )
    await declare_result.wait_for_acceptance()

    return declare_result.class_hash

