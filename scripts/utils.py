from starknet_py.net.account.account_client import AccountClient
from starknet_py.contract import Contract

MAX_FEE = int(1e16)

#Declare and Deploy a Contract
async def declare_and_deploy_contract(client: AccountClient,compiled_contracts: list[str], calldata: list[list[str]]) -> (list[str]):
    
    deployed_contract_addresses = []

    for index in range(len(compiled_contracts)):
        print("index: ", index)
        declare_result = await Contract.declare(
            account=client, compiled_contract=compiled_contracts[index], max_fee=MAX_FEE
        )
        await declare_result.wait_for_acceptance()

        deploy_result = await declare_result.deploy(max_fee=MAX_FEE, constructor_args=calldata[index])
        await deploy_result.wait_for_acceptance()
        contract = deploy_result.deployed_contract
        
        deployed_contract_addresses.append(contract.address)

    return deployed_contract_addresses

#Declare a Contract
async def declare_contract(client: AccountClient,compiled_contract: str) -> (int):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=MAX_FEE
    )
    await declare_result.wait_for_acceptance()

    return declare_result.class_hash

