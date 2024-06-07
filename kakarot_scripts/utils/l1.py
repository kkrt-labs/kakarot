import logging
from typing import Optional, Union, cast

from eth_account import Account as EvmAccount
from eth_account._utils.typed_transactions import TypedTransaction
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from web3 import Web3
from web3.contract import Contract as Web3Contract

from kakarot_scripts.constants import EVM_PRIVATE_KEY
from kakarot_scripts.utils.kakarot import (
    EvmTransactionError,
    get_solidity_artifacts,
    get_vyper_artifacts,
)
from tests.utils.constants import TRANSACTION_GAS_LIMIT

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


anvil_url = "http://127.0.0.1:8545"
anvil_provider = Web3(Web3.HTTPProvider(anvil_url))

if anvil_provider.is_connected():
    logger.info("ℹ️  Connected to Anvil for local development")
else:
    print("Failed to connect to Anvil")


async def deploy_on_l1(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    logger.info(f"⏳ Deploying {contract_name}")
    caller_eoa = kwargs.pop("caller_eoa", None)
    contract = get_l1_contract(contract_app, contract_name)
    max_fee = kwargs.pop("max_fee", None)
    value = kwargs.pop("value", 0)
    receipt, response, success, gas_used = await send_l1_transaction(
        to=0,
        gas=int(TRANSACTION_GAS_LIMIT),
        data=contract.constructor(*args, **kwargs).data_in_transaction,
        caller_eoa=caller_eoa,
        max_fee=max_fee,
        value=value,
    )
    if success == 0:
        raise EvmTransactionError(bytes(response))

    evm_address = int(receipt.contractAddress or receipt.to, 16)
    contract.address = Web3.to_checksum_address(f"0x{evm_address:040x}")
    logger.info(f"✅ {contract_name} deployed at address {contract.address}")

    return contract


def get_l1_contract(
    contract_app: str,
    contract_name: str,
    address=None,
) -> Web3Contract:

    try:
        artifacts = get_solidity_artifacts(contract_app, contract_name)
    except ValueError:
        artifacts = get_vyper_artifacts(contract_app, contract_name)

    contract = cast(
        Web3Contract,
        anvil_provider.eth.contract(
            address=to_checksum_address(address) if address is not None else address,
            abi=artifacts["abi"],
            bytecode=artifacts["bytecode"],
        ),
    )
    contract.bytecode_runtime = HexBytes(artifacts["bytecode_runtime"])

    return contract


async def send_l1_transaction(
    to: Union[int, str],
    data: Union[str, bytes],
    gas: int = 21_000,
    value: Union[int, str] = 0,
    caller_eoa: Optional[EvmAccount] = None,
    max_fee: Optional[int] = None,
):
    """Execute the data at the EVM contract to on Kakarot."""
    evm_account = caller_eoa or EvmAccount.from_key(EVM_PRIVATE_KEY)
    nonce = anvil_provider.eth.get_transaction_count(evm_account.address)
    payload = {
        "type": 0x2,
        "chainId": anvil_provider.eth.chain_id,
        "nonce": nonce,
        "gas": gas,
        "maxPriorityFeePerGas": 1,
        "maxFeePerGas": int(1e9),
        "to": to_checksum_address(to) if to else None,
        "value": value,
        "data": data,
    }

    typed_transaction = TypedTransaction.from_dict(payload)

    evm_tx = EvmAccount.sign_transaction(
        typed_transaction.as_dict(),
        evm_account.key,
    )

    tx_hash = anvil_provider.eth.send_raw_transaction(evm_tx.rawTransaction)
    receipt = anvil_provider.eth.wait_for_transaction_receipt(tx_hash)
    return receipt, [], receipt.status, receipt.gasUsed
