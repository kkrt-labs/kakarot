from starknet_py.net.account.account_client import AccountClient
from starknet_py.contract import Contract

#Deploy a Contract
async def deployContract(client: AccountClient,compiled_contract: str, calldata) -> (str):
    declare_result = await Contract.declare(
        account=client, compiled_contract=compiled_contract, max_fee=int(1e16)
    )
    print("⏳ Waiting for decleration...")
    await declare_result.wait_for_acceptance()

    deploy_result = await declare_result.deploy(max_fee=int(1e16), constructor_args=calldata)
    print("⏳ Waiting for deployment...")
    await deploy_result.wait_for_acceptance()
    contract = deploy_result.deployed_contract
    return hex(contract.address)