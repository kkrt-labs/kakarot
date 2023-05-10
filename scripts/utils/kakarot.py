import json
import logging
from pathlib import Path
from typing import Optional, Union

from eth_account import Account as EvmAccount
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from starknet_py.abi import AbiParser
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account
from starknet_py.net.client_errors import ContractNotFoundError
from starknet_py.net.client_models import Call
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.serialization import serializer_for_function
from starkware.starknet.public.abi import get_selector_from_name
from web3 import Web3
from web3.contract import Contract as Web3Contract

from scripts.artifacts import get_deployments
from scripts.constants import (
    CHAIN_ID,
    DEPLOYMENTS_DIR,
    EVM_ADDRESS,
    EVM_PRIVATE_KEY,
    GATEWAY_CLIENT,
    KAKAROT_CHAIN_ID,
)
from scripts.utils.starknet import deploy_and_fund_evm_address, get_tx_url

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

get_deployments(Path("deployments"))
deployments = json.load(open(DEPLOYMENTS_DIR / "deployments.json", "r"))
KAKAROT_ADDRESS = deployments["kakarot"]["address"]


def get_contract(solidity_contracts_dir: str, contract_app: str, contract_name: str):
    solidity_contracts_dir: Path = Path(solidity_contracts_dir)
    target_solidity_file_path = list(
        (solidity_contracts_dir / contract_app).glob(f"**/{contract_name}.sol")
    )
    if len(target_solidity_file_path) != 1:
        raise ValueError(f"Cannot locate a unique {contract_name} in {contract_app}")

    all_compilation_outputs = [
        json.load(open(file))
        for file in (solidity_contracts_dir / "build").glob(f"**/{contract_name}.json")
    ]

    target_compilation_output = [
        compilation
        for compilation in all_compilation_outputs
        if compilation["metadata"]["settings"]["compilationTarget"].get(
            str(target_solidity_file_path[0])
        )
    ]

    if len(target_compilation_output) != 1:
        raise ValueError(
            f"Cannot locate a unique compilation output for target {target_solidity_file_path[0]}: "
            f"found {len(target_compilation_output)} outputs:\n{target_compilation_output}"
        )

    return Web3().eth.contract(
        abi=target_compilation_output[0]["abi"],
        bytecode=target_compilation_output[0]["bytecode"]["object"],
    )


async def get_contract_at_address(
    solidity_contracts_dir: str,
    contract_app: str,
    contract_name: str,
    evm_address: Union[str, int],
) -> Web3Contract:
    evm_address = evm_address if isinstance(evm_address, str) else hex(evm_address)
    evm_address = Web3.to_checksum_address(evm_address)

    kakarot_contract = await Contract.from_address(KAKAROT_ADDRESS, GATEWAY_CLIENT)
    starknet_address = (
        await kakarot_contract.functions["compute_starknet_address"].call(
            int(evm_address, 16)
        )
    ).contract_address
    if not await contract_exists(starknet_address):
        raise ValueError("Provided EVM address does not have a deployed contract")

    contract = get_contract(solidity_contracts_dir, contract_app, contract_name)
    for fun in contract.functions:
        setattr(contract, fun, classmethod(wrap_kakarot(contract, fun, evm_address)))

    return contract


async def deploy_solidity_contract(
    solidity_contracts_dir: str, contract_app: str, contract_name: str
) -> Web3Contract:
    contract = get_contract(solidity_contracts_dir, contract_app, contract_name)

    deploy_bytecode = contract.bytecode
    tx_hash = await deploy_contract_account(deploy_bytecode)
    receipt = await GATEWAY_CLIENT.get_transaction_receipt(tx_hash=tx_hash)

    if len(receipt.events) != 4:
        raise ValueError(
            f"Contract deployment failed, got {len(receipt.events)} events, expected 4"
        )

    evm_address = Web3.to_checksum_address(hex(receipt.events[2].data[0]))

    for fun in contract.functions:
        setattr(contract, fun, classmethod(wrap_kakarot(contract, fun, evm_address)))

    return contract


def wrap_kakarot(contract: Web3Contract, fun: str, evm_address: str):
    """Wrap a contract function call with the Kakarot contract."""

    async def _wrapper(self, *args, **kwargs):
        abi = contract.get_function_by_name(fun).abi
        gas_price = kwargs.pop("gas_price", 1_000)
        gas_limit = kwargs.pop("gas_limit", 1_000_000_000)
        value = kwargs.pop("value", 0)
        calldata = get_contract_method_calldata(contract, fun, *args, **kwargs)

        if abi["stateMutability"] == "view":
            evm_calldata = list(HexBytes(calldata))
            calldata = [
                int(evm_address, 16),
                gas_limit,
                gas_price,
                value,
                len(evm_calldata),
                *evm_calldata,
            ]
            result = await GATEWAY_CLIENT.call_contract(
                Call(
                    to_addr=int(KAKAROT_ADDRESS, 16),
                    selector=get_selector_from_name("eth_call"),
                    calldata=calldata,
                )
            )
            return (await deserialize_kakarot_execute_output(result)).return_data

        await eth_send_transaction(
            address=evm_address,
            value=value,
            gas_limit=gas_limit,
            calldata=calldata,
        )

    return _wrapper


async def deserialize_kakarot_execute_output(output: list[int]):
    """Deserialize the output of the Kakarot contract's execute_at_address method."""
    if len(output) == 0:
        raise ValueError(f"No output provided for deserialization")

    kakarot_contract = await Contract.from_address(KAKAROT_ADDRESS, GATEWAY_CLIENT)
    kakarot_abi = AbiParser([kakarot_contract.functions["eth_call"].abi]).parse()
    function_parser = serializer_for_function(kakarot_abi.functions["eth_call"])
    return function_parser.deserialize(output)


def get_contract_method_calldata(
    contract: Web3Contract, method_name: str, *args, **kwargs
):
    return contract.get_function_by_name(method_name)(
        *args, **kwargs
    )._encode_transaction_data()


async def contract_exists(address: int) -> bool:
    try:
        await GATEWAY_CLIENT.get_code(address)
        return True
    except ContractNotFoundError:
        return False


async def get_evm_account(
    address=None,
    private_key=None,
) -> Account:
    address = int(address or EVM_ADDRESS, 16)
    private_key = int(private_key or EVM_PRIVATE_KEY, 16)

    kakarot_contract = await Contract.from_address(KAKAROT_ADDRESS, GATEWAY_CLIENT)
    starknet_address = (
        await kakarot_contract.functions["compute_starknet_address"].call(address)
    ).contract_address

    if not await contract_exists(starknet_address):
        await deploy_and_fund_evm_address(hex(address), 0.01)

    return Account(
        address=starknet_address,
        client=GATEWAY_CLIENT,
        chain=CHAIN_ID,
        key_pair=KeyPair(private_key, address),
    )


async def deploy_contract_account(
    bytecode: Union[str, bytes],
):
    """Deploy a contract account with the provided bytecode."""
    evm_account = await get_evm_account()
    bytecode = bytecode.hex() if isinstance(bytecode, bytes) else bytecode

    tx_payload = get_payload(
        data=bytecode, private_key=hex(evm_account.signer.private_key)
    )

    logger.info(f"⏳ Deploying contract account")
    response = await evm_account.execute(
        calls=Call(
            to_addr=int(KAKAROT_ADDRESS, 16),
            selector=get_selector_from_name("deploy_contract_account"),
            calldata=tx_payload,
        ),
        max_fee=int(1e17),
    )
    logger.info(f"⏳ Waiting for tx {get_tx_url(response.transaction_hash)}")
    await evm_account.client.wait_for_tx(
        tx_hash=response.transaction_hash, check_interval=15
    )
    return response.transaction_hash


async def eth_send_transaction(
    address: Union[int, str],
    value: Union[int, str],
    gas_limit: int,
    calldata: Union[str, bytes],
):
    """Execute the calldata at the EVM contract address on Kakarot."""

    evm_account = await get_evm_account()
    address = hex(address) if isinstance(address, int) else address
    value = hex(value) if isinstance(value, int) else value
    calldata = calldata.hex() if isinstance(calldata, bytes) else calldata

    tx_payload = get_payload(
        data=calldata,
        private_key=hex(evm_account.signer.private_key),
        gas_limit=gas_limit,
        destination=address,
        value=value,
    )
    logger.info(f"⏳ Executing the provided bytecode for the contract at {address}")
    response = await evm_account.execute(
        calls=Call(
            to_addr=int(KAKAROT_ADDRESS, 16),
            selector=get_selector_from_name("eth_send_transaction"),
            calldata=tx_payload,
        ),
        max_fee=int(1e17),
    )
    logger.info(f"⏳ Waiting for tx {get_tx_url(response.transaction_hash)}")
    await evm_account.client.wait_for_tx(
        tx_hash=response.transaction_hash, check_interval=15
    )


def get_payload(
    data: str,
    private_key: str,
    gas_limit: int = 0xDEAD,
    tx_type: int = 0x02,
    destination: Optional[str] = None,
    value: str = "0x0",
):
    return EvmAccount.sign_transaction(
        {
            "type": tx_type,
            "chainId": KAKAROT_CHAIN_ID,
            "nonce": 0xDEAD,
            "gas": gas_limit,
            "maxPriorityFeePerGas": 0xDEAD,
            "maxFeePerGas": 0xDEAD,
            "to": destination and to_checksum_address(destination),
            "value": value,
            "data": data,
        },
        private_key,
    ).rawTransaction
