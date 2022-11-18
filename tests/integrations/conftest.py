import logging

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.utils import (
    get_contract,
    hex_string_to_bytes_array,
    traceit,
    wrap_for_kakarot,
)

logger = logging.getLogger()


@pytest_asyncio.fixture(scope="module")
async def kakarot(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
) -> StarknetContract:
    return await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[
            1,
            eth.contract_address,
            contract_account_class.class_hash,
        ],
    )


@pytest_asyncio.fixture(scope="module", autouse=True)
async def set_account_registry(
    kakarot: StarknetContract, account_registry: StarknetContract
):
    await account_registry.transfer_ownership(kakarot.contract_address).execute(
        caller_address=1
    )
    await kakarot.set_account_registry(
        registry_address_=account_registry.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=kakarot.contract_address
    )


@pytest.fixture(scope="module")
def solidity_contract(starknet, contract_account_class, kakarot):

    deployed_contracts = {}

    async def _factory(name, *args, **kwargs):
        if name in deployed_contracts:
            return deployed_contracts[name]
        contract = get_contract(name)
        deploy_bytecode = hex_string_to_bytes_array(
            contract.constructor(*args, **kwargs).data_in_transaction
        )

        with traceit.context(name):
            tx = await kakarot.deploy(bytecode=deploy_bytecode).execute(
                caller_address=1
            )

        starknet_contract_address = tx.result.starknet_contract_address
        contract_account = StarknetContract(
            starknet.state,
            contract_account_class.abi,
            starknet_contract_address,
            tx,
        )

        kakarot_contract = wrap_for_kakarot(
            contract, kakarot, tx.result.evm_contract_address
        )
        setattr(kakarot_contract, "contract_account", contract_account)
        deployed_contracts[name] = kakarot_contract

        return kakarot_contract

    yield _factory

    logger.info(f"Deployed solidity contracts: {list(deployed_contracts)}")
    deployed_contracts = {}
