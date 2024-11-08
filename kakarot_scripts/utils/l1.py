import json
import logging
from types import MethodType
from typing import Optional, cast

from eth_abi import decode
from eth_account import Account as EvmAccount
from eth_account.signers.local import LocalAccount
from eth_typing import Address
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from web3 import Web3
from web3._utils.abi import get_abi_output_types, map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.contract import Contract as Web3Contract
from web3.exceptions import NoABIFunctionsFound
from web3.types import TxParams, Wei

from kakarot_scripts.constants import DEPLOYMENTS_DIR, EVM_PRIVATE_KEY, L1_RPC_PROVIDER
from kakarot_scripts.utils.kakarot import (
    EvmTransactionError,
    _parse_events,
    get_solidity_artifacts,
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


if L1_RPC_PROVIDER.is_connected():
    logger.info(
        f"ℹ️  Connected to L1 RPC with ChainId 0x{L1_RPC_PROVIDER.eth.chain_id:x}"
    )
else:
    print("Failed to connect to L1 RPC")


def dump_l1_addresses(deployments):
    json.dump(
        deployments,
        open(DEPLOYMENTS_DIR / "l1_addresses.json", "w"),
        indent=2,
    )


def get_l1_addresses():
    try:
        return json.load(open(DEPLOYMENTS_DIR / "l1_addresses.json", "r"))
    except FileNotFoundError:
        return {}


def l1_contract_exists(address: HexBytes) -> bool:
    try:
        code = L1_RPC_PROVIDER.eth.get_code(address)
        if len(code) != 0:
            logger.info(f"ℹ️  Contract at address {address} already exists")
            return True
        return False
    except Exception:
        return False


def get_l1_contract(
    contract_app: str,
    contract_name: str,
    address=None,
    caller_eoa: Optional[EvmAccount] = None,
) -> Web3Contract:

    artifacts = get_solidity_artifacts(contract_app, contract_name)

    contract = cast(
        Web3Contract,
        L1_RPC_PROVIDER.eth.contract(
            address=to_checksum_address(address) if address is not None else address,
            abi=artifacts["abi"],
            bytecode=artifacts["bytecode"]["object"],
        ),
    )
    contract.bytecode_runtime = HexBytes(artifacts["bytecode_runtime"]["object"])

    try:
        for fun in contract.functions:
            setattr(contract, fun, MethodType(_wrap_web3(fun, caller_eoa), contract))
    except NoABIFunctionsFound:
        pass
    contract.events.parse_events = MethodType(_parse_events, contract.events)
    return contract


def prepare_l1_transaction(
    to: Optional[Address] = None,
    data: bytes = b"",
    value: Optional[Wei] = None,
    caller_eoa: Optional[LocalAccount] = None,
):
    """Execute the data at the EVM contract on an L1 node."""
    evm_account = caller_eoa or EvmAccount.from_key(EVM_PRIVATE_KEY)
    transaction: TxParams = {
        "to": to_checksum_address(to) if to else "",
        "value": value or Wei(0),
        "data": data,
        "from": evm_account.address,
    }
    transaction["gas"] = L1_RPC_PROVIDER.eth.estimate_gas(transaction)
    transaction["gasPrice"] = L1_RPC_PROVIDER.eth.gas_price
    transaction["chainId"] = L1_RPC_PROVIDER.eth.chain_id
    transaction["nonce"] = L1_RPC_PROVIDER.eth.get_transaction_count(
        evm_account.address
    )

    return transaction


def send_l1_transaction(
    transaction: TxParams,
    caller_eoa: Optional[LocalAccount] = None,
):
    evm_account = caller_eoa or EvmAccount.from_key(EVM_PRIVATE_KEY)
    evm_tx = L1_RPC_PROVIDER.eth.account.sign_transaction(transaction, evm_account.key)
    tx_hash = L1_RPC_PROVIDER.eth.send_raw_transaction(evm_tx.raw_transaction)
    logger.info(f"⏳ Waiting for transaction {tx_hash.hex()}")
    receipt = L1_RPC_PROVIDER.eth.wait_for_transaction_receipt(tx_hash)
    response = []
    if not receipt.status:
        trace = L1_RPC_PROVIDER.manager.request_blocking(
            "debug_traceTransaction", [tx_hash, {"tracer": "callTracer"}]
        )
        response = trace["revertReason"].encode()

    return receipt, response


def deploy_on_l1(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    logger.info(f"⏳ Deploying {contract_name}")
    caller_eoa = kwargs.pop("caller_eoa", None)
    contract = get_l1_contract(contract_app, contract_name)
    value = kwargs.pop("value", 0)
    transaction = prepare_l1_transaction(
        data=contract.constructor(*args, **kwargs).data_in_transaction,
        value=value,
        caller_eoa=caller_eoa,
    )
    receipt, response = send_l1_transaction(transaction, caller_eoa)
    if receipt["status"] == 0:
        raise EvmTransactionError(bytes(response))

    evm_address = int(receipt.contractAddress or receipt.to, 16)
    contract.address = Web3.to_checksum_address(f"0x{evm_address:040x}")
    logger.info(f"✅ {contract_name} deployed at: {contract.address}")

    return contract


def _wrap_web3(fun: str, caller_eoa_: Optional[LocalAccount] = None):
    """Wrap a contract function call with the WEB3 provider."""

    def _wrapper(self, *args, **kwargs):
        abi = self.get_function_by_name(fun).abi
        value = kwargs.pop("value", 0)
        calldata = self.get_function_by_name(fun)(
            *args, **kwargs
        )._encode_transaction_data()
        caller_eoa = kwargs.pop("caller_eoa", caller_eoa_)
        transaction = prepare_l1_transaction(
            to=self.address,
            data=calldata,
            value=value,
            caller_eoa=caller_eoa,
        )

        if abi["stateMutability"] in ["pure", "view"]:
            # Setting gasPrice to 0 to avoid error due to sender balance to low
            result = L1_RPC_PROVIDER.eth.call({**transaction, "gasPrice": 0})
            types = get_abi_output_types(abi)
            decoded = decode(types, bytes(result))
            normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
            return normalized[0] if len(normalized) == 1 else normalized

        logger.info(f"⏳ Executing {fun} at address {self.address}")
        receipt, response = send_l1_transaction(transaction, caller_eoa)
        if receipt["status"] == 0:
            logger.error(f"❌ {self.address}.{fun} failed")
            raise EvmTransactionError(bytes(response))
        logger.info(f"✅ {self.address}.{fun}")
        return receipt, response

    return _wrapper
