import functools
import json
import logging
import os
import re
import subprocess
import requests
from pathlib import Path
from typing import Optional, Union

from caseconverter import snakecase
from starknet_py.contract import Contract
from starknet_py.net.account.account import Account
from starknet_py.net.client import Client
from starknet_py.net.client_models import Call
from starknet_py.net.client_errors import ContractNotFoundError
from starknet_py.net.models import Address
from starknet_py.net.signer.stark_curve_signer import KeyPair
from starknet_py.proxy.contract_abi_resolver import ProxyConfig
from starknet_py.proxy.proxy_check import ProxyCheck
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.wallets.account import DEFAULT_ACCOUNT_DIR

from eth_account import Account
from eth_utils.address import to_checksum_address
from web3.contract import Contract as Web3Contract
from web3 import Web3


from scripts.constants import (
    ACCOUNT_ADDRESS,
    BUILD_DIR,
    CHAIN_ID,
    KAKAROT_CHAIN_ID,
    KAKAROT_ADDRESS,
    CONTRACTS,
    DEPLOYMENTS_NETWORK_DIR,
    ETH_TOKEN_ADDRESS,
    GATEWAY_CLIENT,
    NETWORK,
    PRIVATE_KEY,
    SOURCE_DIR,
    STARKNET_NETWORK,
    STARKSCAN_URL,
    EVM_ADDRESS,
    EVM_PRIVATE_KEY,
)

logging.basicConfig()
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

DEPLOYMENTS_NETWORK_DIR.mkdir(exist_ok=True, parents=True)
BUILD_DIR.mkdir(exist_ok=True, parents=True)


def int_to_uint256(value):
    value = int(value)
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return {"low": low, "high": high}


async def create_account():
    env = os.environ.copy()
    env[
        "STARKNET_WALLET"
    ] = "starkware.starknet.wallets.open_zeppelin.OpenZeppelinAccount"
    env["STARKNET_NETWORK"] = STARKNET_NETWORK
    logger.info(
        f"⏳ Creating account on network {STARKNET_NETWORK} with {GATEWAY_CLIENT.net}"
    )
    output = subprocess.run(
        ["starknet", "new_account", "--account", "kakarot"],
        env=env,
        capture_output=True,
    )
    if output.returncode != 0:
        raise Exception(output.stderr.decode())
    account_address = re.search(
        r"account address: (.*)", (output.stdout.decode() + output.stderr.decode()).lower()  # type: ignore
    )[1]
    logger.info(f"✅ Starknet account created locally with address {account_address}")
    input(f"Send ETH to {account_address} and press enter to continue")
    output = subprocess.run(
        [
            "starknet",
            "deploy_account",
            "--account",
            "kakarot",
            "--gateway_url",
            f"{GATEWAY_CLIENT.net}/gateway",
            "--feeder_gateway_url",
            f"{GATEWAY_CLIENT.net}/feeder_gateway",
        ],
        env=env,
        capture_output=True,
    )
    if output.returncode != 0:
        raise Exception(output.stderr.decode())
    transaction_hash = re.search(
        r"transaction hash: (.*)", (output.stdout.decode() + output.stderr.decode()).lower()  # type: ignore
    )[1]
    await GATEWAY_CLIENT.wait_for_tx(transaction_hash)


async def get_default_account() -> Account:
    accounts = json.load(
        open(list(Path(DEFAULT_ACCOUNT_DIR).expanduser().glob("*.json"))[0])
    )
    account = accounts.get(STARKNET_NETWORK, {}).get("kakarot")
    if account is None:
        await create_account()

    logger.info(f"ℹ️  Using account {account['address']:x}")

    return Account(
        address=account["address"],
        client=GATEWAY_CLIENT,
        chain=CHAIN_ID,
        key_pair=KeyPair(
            private_key=int(account["private_key"], 16),
            public_key=int(account["public_key"], 16),
        ),
    )


async def get_starknet_account(
    address=None,
    private_key=None,
) -> Account:
    address = int(address or ACCOUNT_ADDRESS, 16)
    key_pair = KeyPair.from_private_key(int(private_key or PRIVATE_KEY, 16))
    try:
        call = Call(
            to_addr=address,
            selector=get_selector_from_name("get_public_key"),
            calldata=[],
        )
        public_key = await GATEWAY_CLIENT.call_contract(call=call, block_hash="pending")
    except Exception as err:
        if (
            json.loads(re.findall("{.*}", err.args[0], re.DOTALL)[0])["code"]
            == "StarknetErrorCode.ENTRY_POINT_NOT_FOUND_IN_CONTRACT"
        ):
            call = Call(
                to_addr=address,
                selector=get_selector_from_name("getPublicKey"),
                calldata=[],
            )
            public_key = await GATEWAY_CLIENT.call_contract(
                call=call, block_hash="pending"
            )
        else:
            raise err
    if key_pair.public_key != public_key[0]:
        raise ValueError(
            f"Public key of account 0x{address:064x} is not consistent with provided private key"
        )

    return Account(
        address=address,
        client=GATEWAY_CLIENT,
        chain=CHAIN_ID,
        key_pair=key_pair,
    )


async def contract_exists(address: int) -> bool:
    try:
        await GATEWAY_CLIENT.get_code(address)
        return True
    except ContractNotFoundError:
        return False


async def get_evm_account() -> AccountClient:
    starknet_account = await get_starknet_account()
    kakarot_contract = await Contract.from_address(KAKAROT_ADDRESS, GATEWAY_CLIENT)
    starknet_address = (
        await kakarot_contract.functions["compute_starknet_address"].call(
            int(EVM_ADDRESS, 16)
        )
    ).contract_address

    if not await contract_exists(starknet_address):
        call = Call(
            to_addr=int(KAKAROT_ADDRESS, 16),
            selector=get_selector_from_name("deploy_externally_owned_account"),
            calldata=[int(EVM_ADDRESS, 16)],
        )
        logger.info(f"⏳ Deploying EOA account")
        tx_hash = (
            await starknet_account.execute(call, max_fee=int(10e16))
        ).transaction_hash
        logger.info(f"⏳ Waiting for tx {get_tx_url(tx_hash)}")
        await starknet_account.wait_for_tx(tx_hash)
        await fund_address(starknet_address, 0.005)

    return AccountClient(
        address=starknet_address,
        client=GATEWAY_CLIENT,
        supported_tx_version=1,
        chain=CHAIN_ID,
        key_pair=KeyPair(int(EVM_PRIVATE_KEY, 16), int(EVM_ADDRESS, 16)),
    )


async def get_eth_contract() -> Contract:
    account = await get_starknet_account()

    class EthProxyCheck(ProxyCheck):
        """
        See https://github.com/software-mansion/starknet.py/issues/856
        """

        async def implementation_address(
            self, address: Address, client: Client
        ) -> Optional[int]:
            return await self.get_implementation(address, client)

        async def implementation_hash(
            self, address: Address, client: Client
        ) -> Optional[int]:
            return await self.get_implementation(address, client)

        @staticmethod
        async def get_implementation(address: Address, client: Client) -> Optional[int]:
            call = Call(
                to_addr=address,
                selector=get_selector_from_name("implementation"),
                calldata=[],
            )
            (implementation,) = await client.call_contract(call=call)
            return implementation

    proxy_config = (
        ProxyConfig(proxy_checks=[EthProxyCheck()]) if NETWORK != "devnet" else False
    )
    return await Contract.from_address(
        ETH_TOKEN_ADDRESS, account, proxy_config=proxy_config
    )


async def get_contract(contract_name) -> Contract:
    return await Contract.from_address(
        get_deployments()[contract_name]["address"],
        await get_starknet_account(),
    )


async def fund_address(address: Union[int, str], amount: float):
    """
    Fund a given starknet address with {amount} ETH
    """
    address = int(address, 16) if isinstance(address, str) else address
    amount = amount * 1e18
    if NETWORK == "devnet":
        response = requests.post(
            f"{GATEWAY_CLIENT.net}/mint", json={"address": address, "amount": amount}
        )
        if response.status_code != 200:
            logger.error(f"Cannot mint token to {address}: {response.text}")
        logger.info(f"{amount / 1e18} ETH minted to {address}")
    else:
        account = await get_starknet_account()
        eth_contract = await get_eth_contract()
        balance = (await eth_contract.functions["balanceOf"].call(account.address)).balance  # type: ignore
        if balance < amount:
            raise ValueError(
                f"Cannot send {amount / 1e18} ETH from default account with current balance {balance / 1e18} ETH"
            )
        tx = await eth_contract.functions["transfer"].invoke(
            address, int_to_uint256(amount), max_fee=int(10e16)
        )
        await tx.wait_for_acceptance()
        logger.info(
            f"{amount / 1e18} ETH sent from {hex(account.address)} to {hex(address)}"
        )


async def deploy_and_fund_evm_address(evm_address: str, amount: float):
    """
    Deploy an EOA linked to the given EVM address and fund it with amount ETH
    """
    await invoke("kakarot", "deploy_externally_owned_account", int(evm_address, 16))
    starknet_address = await call(
        "kakarot", "compute_starknet_address", int(evm_address, 16)
    )
    await fund_address(starknet_address[0], amount)


def dump_declarations(declarations):
    json.dump(
        {name: hex(class_hash) for name, class_hash in declarations.items()},
        open(DEPLOYMENTS_NETWORK_DIR / "declarations.json", "w"),
        indent=2,
    )


def get_declarations():
    return {
        name: int(class_hash, 16)
        for name, class_hash in json.load(
            open(DEPLOYMENTS_NETWORK_DIR / "declarations.json")
        ).items()
    }


def dump_deployments(deployments):
    json.dump(
        {
            name: {
                **deployment,
                "address": hex(deployment["address"]),
                "tx": hex(deployment["tx"]),
                "artifact": str(deployment["artifact"]),
            }
            for name, deployment in deployments.items()
        },
        open(DEPLOYMENTS_NETWORK_DIR / "deployments.json", "w"),
        indent=2,
    )


def get_deployments():
    return json.load(open(DEPLOYMENTS_NETWORK_DIR / "deployments.json", "r"))


def get_artifact(contract_name):
    return BUILD_DIR / f"{contract_name}.json"


def get_abi(contract_name):
    return BUILD_DIR / f"{contract_name}_abi.json"


def get_alias(contract_name):
    return snakecase(contract_name)


def get_tx_url(tx_hash: int) -> str:
    return f"{STARKSCAN_URL}/tx/0x{tx_hash:064x}"


def compile_contract(contract_name):
    contract_file = CONTRACTS.get(contract_name)
    if contract_file is None:
        raise ValueError(
            f"Cannot find {SOURCE_DIR}/**/{contract_name}.cairo in {os.getcwd()}"
        )
    output = subprocess.run(
        [
            "starknet-compile",
            contract_file,
            "--output",
            BUILD_DIR / f"{contract_name}.json",
            "--abi",
            BUILD_DIR / f"{contract_name}_abi.json",
            *(["--disable_hint_validation"] if NETWORK == "devnet" else []),
        ],
        capture_output=True,
    )
    if output.returncode != 0:
        raise RuntimeError(output.stderr)


async def declare(contract_name):
    logger.info(f"⏳ Declaring {contract_name}")
    account = await get_starknet_account()
    artifact = get_artifact(contract_name)
    declare_transaction = await account.sign_declare_transaction(
        compiled_contract=Path(artifact).read_text(), max_fee=int(10e16)
    )
    resp = await account.client.declare(transaction=declare_transaction)
    logger.info(f"⏳ Waiting for tx {get_tx_url(resp.transaction_hash)}")
    await account.client.wait_for_tx(resp.transaction_hash, check_interval=15)
    logger.info(f"✅ {contract_name} class hash: {hex(resp.class_hash)}")
    return resp.class_hash


async def deploy(contract_name, *args):
    logger.info(f"⏳ Deploying {contract_name}")
    abi = json.loads(Path(get_abi(contract_name)).read_text())
    account = await get_starknet_account()
    deploy_result = await Contract.deploy_contract(
        account=account,
        class_hash=get_declarations()[contract_name],
        abi=abi,
        constructor_args=list(args),
        max_fee=int(10e16),
    )
    logger.info(f"⏳ Waiting for tx {get_tx_url(deploy_result.hash)}")
    await deploy_result.wait_for_acceptance(check_interval=15)
    logger.info(
        f"✅ {contract_name} deployed at: {hex(deploy_result.deployed_contract.address)}"
    )
    return {
        "address": deploy_result.deployed_contract.address,
        "tx": deploy_result.hash,
        "artifact": get_artifact(contract_name),
    }


async def invoke(contract_name, function_name, *inputs, address=None):
    account = await get_starknet_account()
    deployments = get_deployments()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    call = contract.functions[function_name].prepare(*inputs, max_fee=int(10e16))
    logger.info(f"⏳ Invoking {contract_name}.{function_name}({json.dumps(inputs)})")
    response = await account.execute(call, max_fee=int(10e16))
    logger.info(f"⏳ Waiting for tx {get_tx_url(response.transaction_hash)}")
    await account.client.wait_for_tx(response.transaction_hash, check_interval=15)
    logger.info(
        f"✅ {contract_name}.{function_name} invoked at tx: %s",
        hex(response.transaction_hash),
    )
    return response.transaction_hash


async def call(contract_name, function_name, *inputs, address=None):
    deployments = get_deployments()
    account = await get_starknet_account()
    contract = Contract(
        deployments[contract_name]["address"] if address is None else address,
        json.load(open(get_artifact(contract_name)))["abi"],
        account,
    )
    return await contract.functions[function_name].call(*inputs)


def get_contract(contract_path: str) -> Web3Contract:
    path = os.path.splitext(contract_path)[0]
    folder, contract_name = os.path.split(path)
    compilation_output = json.load(
        open(
            Path(folder) / "build" / f"{contract_name}.sol" / f"{contract_name}.json",
            "r",
        )
    )
    return Web3().eth.contract(
        abi=compilation_output["abi"], bytecode=compilation_output["bytecode"]["object"]
    )


def get_contract_deployment_bytecode(contract: Web3Contract):
    return contract.bytecode


def get_contract_method_calldata(
    contract: Web3Contract, method_name: str, *args, **kwargs
):
    return contract.get_function_by_name(method_name)(
        *args, **kwargs
    )._encode_transaction_data()


async def deploy_contract_account(
    bytecode: bytes,
):
    """Deploy a contract account with the provided bytecode."""
    evm_account = await get_evm_account()
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
        max_fee=int(10e16),
    )
    logger.info(f"⏳ Waiting for tx {get_tx_url(response.transaction_hash)}")
    await evm_account.wait_for_tx(tx_hash=response.transaction_hash, check_interval=15)


async def execute_at_address(
    address: Union[int, str], value: Union[int, str], gas_limit: int, calldata: bytes
):
    """Execute the calldata at the EVM contract address on Kakarot."""

    address = hex(address) if isinstance(address, int) else address
    value = hex(value) if isinstance(value, int) else value
    evm_account = await get_evm_account()
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
            selector=get_selector_from_name("execute_at_address"),
            calldata=tx_payload,
        ),
        max_fee=int(10e16),
    )
    logger.info(f"⏳ Waiting for tx {get_tx_url(response.transaction_hash)}")
    await evm_account.wait_for_tx(tx_hash=response.transaction_hash, check_interval=15)


def get_payload(
    data: bytes,
    private_key: str,
    gas_limit: int = 0xDEAD,
    tx_type: int = 0x02,
    destination: Optional[str] = None,
    value: str = "0x0",
):
    return Account.sign_transaction(
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


@functools.wraps(GATEWAY_CLIENT.wait_for_tx)
async def wait_for_transaction(*args, **kwargs):
    return await GATEWAY_CLIENT.wait_for_tx(*args, **kwargs)
