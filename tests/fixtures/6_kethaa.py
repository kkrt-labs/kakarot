import os
from typing import Tuple
import pytest_asyncio
import web3
from eth_account.account import Account, SignedMessage
from eth_keys import keys
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

@pytest_asyncio.fixture(scope="session")
async def externally_owned_account_class(
    starknet: Starknet
):
    account_class = await starknet.declare(
        source=os.path.join(
            os.path.dirname(__file__), "../../src/kakarot/accounts/eoa/aa/externally_owned_account.cairo"
        ),
        cairo_path=[os.path.join(os.path.dirname(__file__), "../../src")],
    )
    return account_class

@pytest_asyncio.fixture(scope="session")
async def deployer(
    starknet: Starknet,
    externally_owned_account_class,
) -> StarknetContract:
    deployer = await starknet.deploy(
        source=os.path.join(
            os.path.dirname(__file__),
            "../../src/kakarot/accounts/eoa/deployer/deployer.cairo",
        ),
        cairo_path=[os.path.join(os.path.dirname(__file__), "../../src")],
        constructor_calldata=[externally_owned_account_class.class_hash],
    )

    return deployer

@pytest_asyncio.fixture(scope="package")
async def externally_owned_account(
    starknet: Starknet,
    externally_owned_account_class,
    deployer,
    kakarot
) -> Tuple[StarknetContract, StarknetContract, bytes, int, web3.Account]:
    private_key = os.urandom(32)
    tempAccount: Account = web3.eth.Account().from_key(private_key)
    evm_address = web3.Web3().toInt(hexstr=tempAccount.address)
    evm_eoa = web3.Account.from_key(keys.PrivateKey(private_key_bytes=private_key))
    eth_aa_deploy_tx = await deployer.create_account(evm_address=evm_address, kakarot_address=kakarot.contract_address).execute()

    account = StarknetContract(
        starknet.state,
        externally_owned_account_class.abi,
        eth_aa_deploy_tx.call_info.internal_calls[0].contract_address,
        eth_aa_deploy_tx,
    )

    return deployer, account, private_key, evm_address, evm_eoa
