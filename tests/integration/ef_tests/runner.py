from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from state_management import (
    fund_and_set_allowance,
    write_test_state_for_contract,
    write_test_state_for_eoa,
)

from tests.utils.helpers import hex_string_to_bytes_array
from tests.utils.uint256 import int_to_uint256
from utils import display_storage, is_account_eoa


async def write_test_state(
    account_proxy_class: DeclaredClass,
    contract_account_class: DeclaredClass,
    externally_owned_account_class: DeclaredClass,
    get_contract_account,
    get_starknet_address,
    eth: StarknetContract,
    kakarot: StarknetContract,
    starknet: StarknetContract,
    pre_state,
):
    """
    Initialize the Starknet state using an ef-test BlockchainTest format case 'pre' field.

    See: https://ethereum-tests.readthedocs.io/en/latest/test_filler/blockchain_filler.html#pre for details.
    """
    for address, state in pre_state.items():
        evm_address = int(address, 16)
        starknet_address = get_starknet_address(evm_address)

        balance = int_to_uint256(int(state["balance"], 16))
        await fund_and_set_allowance(
            eth, kakarot.contract_address, starknet_address, balance
        )

        if is_account_eoa(state):
            await write_test_state_for_eoa(
                externally_owned_account_class.class_hash,
                account_proxy_class.class_hash,
                kakarot,
                starknet,
                state,
                evm_address,
                starknet_address,
            )
        else:
            contract = get_contract_account(starknet_address)
            await write_test_state_for_contract(
                contract_account_class.class_hash,
                account_proxy_class.class_hash,
                contract,
                kakarot,
                starknet,
                state,
                evm_address,
                starknet_address,
            )


async def do_transaction(
    blocks,
    get_starknet_address,
    kakarot: StarknetContract,
    owner,
    starknet: StarknetContract,
):
    """
    Execute each transaction in each block using an ef-test BlockchainTest format's `blocks` field.

    See: https://ethereum-tests.readthedocs.io/en/latest/test_filler/blockchain_filler.html#blocks for details.
    """
    for block in blocks:
        transactions = block["transactions"]

        for transaction in transactions:
            starknet_address = get_starknet_address(int(transaction["sender"], 16))

            await kakarot.eth_send_transaction(
                to=int(transaction["to"], 16),
                gas_limit=int(transaction["gasLimit"], 16),
                gas_price=int(transaction["gasPrice"], 16),
                value=int(transaction["value"], 16),
                data=hex_string_to_bytes_array(transaction["data"]),
            ).execute(caller_address=starknet_address)

            # do we really have to do this manually? (yes)
            await starknet.state.state.increment_nonce(starknet_address)


async def assert_eoa_post_state(
    address, starknet, starknet_address, expected_post_state
):
    actual_nonce = await starknet.state.state.get_nonce_at(starknet_address)
    assert actual_nonce == int(
        expected_post_state["nonce"], 16
    ), f"{expected_post_state['nonce']} of {starknet_address} is not {actual_nonce}"
    assert not expected_post_state[
        "storage"
    ], f"EOA {address} should have empty post state, but got {expected_post_state['storage']}"


async def assert_contract_post_state(
    address, contract, starknet, starknet_address, expected_post_state
):
    actual_nonce = (await contract.get_nonce().call()).result.nonce

    assert actual_nonce == int(
        expected_post_state["nonce"], 16
    ), f"{expected_post_state['nonce']} of {starknet_address} is not {actual_nonce}"

    for key, expected_storage in expected_post_state["storage"].items():
        key = int_to_uint256(int(key, 16))
        expected_storage = int_to_uint256(int(expected_storage, 16))
        actual_storage = (await contract.storage(key).call()).result.value

        assert (
            actual_storage == expected_storage
        ), f"Contract {address} has expected storage={display_storage(expected_storage)} is not actual_storage={display_storage(actual_storage)}"


async def assert_post_state(
    get_contract_account,
    get_starknet_address,
    eth: StarknetContract,
    kakarot: StarknetContract,
    starknet: StarknetContract,
    expected_post_state,
):
    for address, post_state in expected_post_state.items():
        evm_address = int(address, 16)
        starknet_address = get_starknet_address(evm_address)

        if is_account_eoa(post_state):
            await assert_eoa_post_state(address, starknet, starknet_address, post_state)
        else:
            contract = get_contract_account(starknet_address)
            await assert_contract_post_state(
                address, contract, starknet, starknet_address, post_state
            )
