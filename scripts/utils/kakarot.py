import json
import logging
from pathlib import Path
from types import MethodType
from typing import Union, cast

import toml
from eth_account import Account as EvmAccount
from eth_utils.address import to_checksum_address
from hexbytes import HexBytes
from starknet_py.net.account.account import Account
from starknet_py.net.client_errors import ClientError
from starknet_py.net.client_models import Call
from starknet_py.net.signer.stark_curve_signer import KeyPair
from web3 import Web3
from web3._utils.abi import map_abi_data
from web3._utils.normalizers import BASE_RETURN_NORMALIZERS
from web3.contract import Contract as Web3Contract

from scripts.artifacts import fetch_deployments
from scripts.constants import (
    CLIENT,
    EVM_ADDRESS,
    EVM_PRIVATE_KEY,
    KAKAROT_CHAIN_ID,
    NETWORK,
)
from scripts.utils.starknet import call as _call_starknet
from scripts.utils.starknet import fund_address as _fund_starknet_address
from scripts.utils.starknet import get_contract as _get_starknet_contract
from scripts.utils.starknet import get_deployments
from scripts.utils.starknet import invoke as _invoke_starknet
from scripts.utils.starknet import wait_for_transaction

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

if not NETWORK["devnet"]:
    try:
        fetch_deployments()
    except Exception as e:
        logger.warn(f"Using network {NETWORK}, couldn't fetch deployment, error:\n{e}")
KAKAROT_ADDRESS = get_deployments()["kakarot"]["address"]
FOUNDRY_FILE = toml.loads((Path(__file__).parents[2] / "foundry.toml").read_text())
SOLIDITY_CONTRACTS_DIR = Path(FOUNDRY_FILE["profile"]["default"]["src"])


def get_contract(contract_app: str, contract_name: str, address=None) -> Web3Contract:
    target_solidity_file_path = list(
        (SOLIDITY_CONTRACTS_DIR / contract_app).glob(f"**/{contract_name}.sol")
    )
    if len(target_solidity_file_path) != 1:
        raise ValueError(f"Cannot locate a unique {contract_name} in {contract_app}")

    all_compilation_outputs = [
        json.load(open(file))
        for file in (SOLIDITY_CONTRACTS_DIR / "build").glob(f"**/{contract_name}.json")
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

    contract = cast(
        Web3Contract,
        Web3().eth.contract(
            address=to_checksum_address(address) if address is not None else address,
            abi=target_compilation_output[0]["abi"],
            bytecode=target_compilation_output[0]["bytecode"]["object"],
        ),
    )

    for fun in contract.functions:
        setattr(contract, fun, MethodType(_wrap_kakarot(fun), contract))

    return contract


async def deploy(
    contract_app: str, contract_name: str, *args, **kwargs
) -> Web3Contract:
    contract = get_contract(contract_app, contract_name)
    logger.info(f"⏳ Deploying {contract_name}")
    receipt = await eth_send_transaction(
        to=0,
        value=0,
        gas=int(1e18),
        data=contract.constructor(*args, **kwargs).data_in_transaction,
    )
    deploy_event = [
        event
        for event in receipt.events
        if event.from_address == int(get_deployments()["kakarot"]["address"], 16)
    ]
    if len(deploy_event) != 1:
        raise ValueError(
            f"Cannot locate evm contract address event, receipt events:\n{receipt.events}"
        )
    evm_address, _ = deploy_event[0].data
    contract.address = Web3.to_checksum_address(evm_address)

    for fun in contract.functions:
        setattr(contract, fun, MethodType(_wrap_kakarot(fun), contract))

    logger.info(f"✅ {contract_name} deployed at address {contract.address}")
    return contract


def _wrap_kakarot(fun: str):
    """Wrap a contract function call with the Kakarot contract."""

    async def _wrapper(self, *args, **kwargs):
        abi = self.get_function_by_name(fun).abi
        gas_price = kwargs.pop("gas_price", 1_000)
        gas_limit = kwargs.pop("gas_limit", 1_000_000_000)
        value = kwargs.pop("value", 0)
        calldata = self.get_function_by_name(fun)(
            *args, **kwargs
        )._encode_transaction_data()

        if abi["stateMutability"] == "view":
            kakarot_contract = await _get_starknet_contract("kakarot")
            result = await kakarot_contract.functions["eth_call"].call(
                origin=EVM_ADDRESS,
                to=int(self.address, 16),
                gas_limit=gas_limit,
                gas_price=gas_price,
                value=value,
                data=list(HexBytes(calldata)),
            )
            codec = Web3().codec
            types = [o["type"] for o in abi["outputs"]]
            decoded = codec.decode(types, bytes(result.return_data))
            normalized = map_abi_data(BASE_RETURN_NORMALIZERS, types, decoded)
            return normalized[0] if len(normalized) == 1 else normalized

        logger.info(f"⏳ Executing {fun} at address {self.address}")
        return await eth_send_transaction(
            to=self.address,
            value=value,
            gas=gas_limit,
            data=calldata,
        )

    return _wrapper


async def _contract_exists(address: int) -> bool:
    try:
        await CLIENT.get_class_hash_at(address)
        return True
    except ClientError:
        return False


async def get_eoa(
    address=None,
    private_key=None,
) -> Account:
    address = int(address or EVM_ADDRESS, 16)
    private_key = int(private_key or EVM_PRIVATE_KEY, 16)

    starknet_address = await _get_starknet_address(address)
    if not await _contract_exists(starknet_address):
        await deploy_and_fund_evm_address(hex(address), 0.1)

    return Account(
        address=starknet_address,
        client=CLIENT,
        chain=NETWORK["chain_id"],
        key_pair=KeyPair(private_key, address),
    )


async def eth_send_transaction(
    to: Union[int, str],
    value: Union[int, str],
    gas: int,
    data: Union[str, bytes],
):
    """Execute the data at the EVM contract to on Kakarot."""
    evm_account = await get_eoa()
    tx_payload = EvmAccount.sign_transaction(
        {
            "type": 0x2,
            "chainId": KAKAROT_CHAIN_ID,
            "nonce": await evm_account.get_nonce(),
            "gas": gas,
            "maxPriorityFeePerGas": int(1e19),
            "maxFeePerGas": int(1e19),
            "to": to_checksum_address(to) if to else None,
            "value": value,
            "data": data,
        },
        hex(evm_account.signer.private_key),
    ).rawTransaction
    response = await evm_account.execute(
        calls=Call(
            to_addr=0xDEAD,  # unused in current EOA implementation
            selector=0xDEAD,  # unused in current EOA implementation
            calldata=tx_payload,
        ),
        max_fee=int(5e17),
    )
    await wait_for_transaction(tx_hash=response.transaction_hash)
    return await CLIENT.get_transaction_receipt(response.transaction_hash)


async def _get_starknet_address(address: Union[str, int]):
    evm_address = int(address, 16) if isinstance(address, str) else address
    kakarot_contract = await _get_starknet_contract("kakarot")
    return (
        await kakarot_contract.functions["compute_starknet_address"].call(evm_address)
    ).contract_address


async def deploy_and_fund_evm_address(evm_address: str, amount: float):
    """
    Deploy an EOA linked to the given EVM address and fund it with amount ETH
    """

    await fund_address(evm_address, amount)

    starknet_address = (
        await _call_starknet(
            "kakarot", "compute_starknet_address", int(evm_address, 16)
        )
    ).contract_address
    if not await _contract_exists(starknet_address):
        await _invoke_starknet(
            "kakarot", "deploy_externally_owned_account", int(evm_address, 16)
        )


async def fund_address(address: Union[str, int], amount: float):
    starknet_address = await _get_starknet_address(address)
    logger.info(
        f"ℹ️  Funding EVM address {address} at Starknet address {hex(starknet_address)}"
    )
    await _fund_starknet_address(starknet_address, amount)
