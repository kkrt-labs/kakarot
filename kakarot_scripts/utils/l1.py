import json
import logging
from types import MethodType
from typing import Optional, Union, cast

from eth_abi import decode
from eth_account import Account as EvmAccount
from eth_account.typed_transactions import TypedTransaction
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from web3 import Web3
from web3._utils.abi import get_abi_output_types, map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.contract import Contract as Web3Contract
from web3.exceptions import NoABIFunctionsFound

from kakarot_scripts.constants import (
    DEFAULT_GAS_PRICE,
    DEPLOYMENTS_DIR,
    EVM_ADDRESS,
    EVM_PRIVATE_KEY,
    L1_RPC_PROVIDER,
)
from kakarot_scripts.utils.kakarot import (
    EvmTransactionError,
    _parse_events,
    get_solidity_artifacts,
)
from tests.utils.constants import TRANSACTION_GAS_LIMIT

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


if L1_RPC_PROVIDER.is_connected():
    logger.info("ℹ️  Connected to L1 RPC")
else:
    print("Failed to connect to L1 RPC")


def dump_l1_addresses(deployments):
    json.dump(
        deployments,
        open(DEPLOYMENTS_DIR / "l1-addresses.json", "w"),
        indent=2,
    )


def get_l1_addresses():
    try:
        return json.load(open(DEPLOYMENTS_DIR / "l1-addresses.json", "r"))
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


def deploy_on_l1(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    logger.info(f"⏳ Deploying {contract_name}")
    caller_eoa = kwargs.pop("caller_eoa", None)
    contract = get_l1_contract(contract_app, contract_name)
    value = kwargs.pop("value", 0)
    receipt, response, success, gas_used = send_l1_transaction(
        to=0,
        gas=int(TRANSACTION_GAS_LIMIT),
        data=contract.constructor(*args, **kwargs).data_in_transaction,
        caller_eoa=caller_eoa,
        value=value,
    )
    if success == 0:
        raise EvmTransactionError(bytes(response))

    evm_address = int(receipt.contractAddress or receipt.to, 16)
    contract.address = Web3.to_checksum_address(f"0x{evm_address:040x}")
    logger.info(f"✅ {contract_name} deployed at: {contract.address}")

    return contract


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


def send_l1_transaction(
    to: Union[int, str],
    data: Union[str, bytes],
    gas: int = 21_000,
    caller_eoa: Optional[EvmAccount] = None,
    value: Union[int, str] = 0,
):
    """Execute the data at the EVM contract on an L1 node."""
    evm_account = caller_eoa or EvmAccount.from_key(EVM_PRIVATE_KEY)
    nonce = L1_RPC_PROVIDER.eth.get_transaction_count(evm_account.address)
    payload = {
        "type": 0x2,
        "chainId": L1_RPC_PROVIDER.eth.chain_id,
        "nonce": nonce,
        "gas": gas,
        "maxPriorityFeePerGas": 1,
        "maxFeePerGas": DEFAULT_GAS_PRICE,
        "to": to_checksum_address(to) if to else None,
        "value": value,
        "data": data,
    }

    typed_transaction = TypedTransaction.from_dict(payload)

    evm_tx = EvmAccount.sign_transaction(
        typed_transaction.as_dict(),
        evm_account.key,
    )

    tx_hash = L1_RPC_PROVIDER.eth.send_raw_transaction(evm_tx.raw_transaction)
    receipt = L1_RPC_PROVIDER.eth.wait_for_transaction_receipt(tx_hash)
    response = []
    if not receipt.status:
        trace = L1_RPC_PROVIDER.manager.request_blocking(
            "debug_traceTransaction", [tx_hash, {"tracer": "callTracer"}]
        )
        print(trace)
        response = bytes(HexBytes(trace["returnValue"]))

    return receipt, response, receipt.status, receipt.gasUsed


def _wrap_web3(fun: str, caller_eoa_: Optional[EvmAccount] = None):
    """Wrap a contract function call with the WEB3 provider."""

    def _wrapper(self, *args, **kwargs):
        abi = self.get_function_by_name(fun).abi
        gas_price = kwargs.pop("gas_price", DEFAULT_GAS_PRICE)
        gas_limit = kwargs.pop("gas_limit", TRANSACTION_GAS_LIMIT)
        value = kwargs.pop("value", 0)
        calldata = self.get_function_by_name(fun)(
            *args, **kwargs
        )._encode_transaction_data()

        if abi["stateMutability"] in ["pure", "view"]:
            origin = (
                int(caller_eoa_.signer.public_key.to_address(), 16)
                if caller_eoa_
                else int(EVM_ADDRESS, 16)
            )
            nonce = L1_RPC_PROVIDER.eth.get_transaction_count(
                Web3.to_checksum_address(f"{origin:040x}")
            )
            payload = {
                "nonce": nonce,
                "from": Web3.to_checksum_address(f"{origin:040x}"),
                "to": self.address,
                "gas_limit": gas_limit,
                "gas_price": gas_price,
                "value": value,
                "data": HexBytes(calldata),
                "access_list": [],
            }
            result = L1_RPC_PROVIDER.eth.call(payload)
            types = get_abi_output_types(abi)
            decoded = decode(types, bytes(result))
            normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
            return normalized[0] if len(normalized) == 1 else normalized

        logger.info(f"⏳ Executing {fun} at address {self.address}")
        receipt, response, success, gas_used = send_l1_transaction(
            to=self.address,
            value=value,
            gas=gas_limit,
            data=calldata,
            caller_eoa=caller_eoa_ if caller_eoa_ else None,
        )
        if success == 0:
            logger.error(f"❌ {self.address}.{fun} failed")
            raise EvmTransactionError(bytes(response))
        logger.info(f"✅ {self.address}.{fun}")
        return {
            "receipt": receipt,
            "response": response,
            "success": success,
            "gas_used": gas_used,
        }

    return _wrapper
