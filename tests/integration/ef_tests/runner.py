from starkware.starknet.public.abi import get_storage_var_address
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract

from tests.integration.ef_tests.utils import display_storage, is_account_eoa
from tests.utils.constants import MAX_INT
from tests.utils.helpers import hex_string_to_bytes_array
from tests.utils.uint256 import int_to_uint256


async def setup_test_state(
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

        await starknet.state.state.set_class_hash_at(
            contract_address=starknet_address,
            class_hash=account_proxy_class.class_hash,
        )

        storage_entries = (
            (("is_initialized",), 1),
            (("evm_address",), evm_address),
            (("evm_to_starknet_address", starknet_address), evm_address),
        ) + (
            (
                (("kakarot_address",), kakarot.contract_address),
                (("_implementation",), externally_owned_account_class.class_hash),
            )
            if is_account_eoa(state)
            else (
                (("Ownable_owner",), kakarot.contract_address),
                (("_implementation",), contract_account_class.class_hash),
                (("nonce",), 1),
            )
        )

        for storage_var, value in storage_entries:
            await starknet.state.state.set_storage_at(
                contract_address=starknet_address,
                key=get_storage_var_address(*storage_var),
                value=value,
            )

        balance = int_to_uint256(int(state["balance"], 16))

        await eth.mint(starknet_address, balance).execute()
        # In regular kakarot deployment, this is handled on construction.
        # We do this manually in order to be able to do tranfsers from our
        # manually deployed accounts.
        await eth.approve(kakarot.contract_address, int_to_uint256(MAX_INT)).execute(
            caller_address=starknet_address
        )

        if not is_account_eoa(state):
            contract = get_contract_account(starknet_address)
            await contract.write_bytecode(
                hex_string_to_bytes_array(state["code"])
            ).execute(caller_address=kakarot.contract_address)


async def assert_post_state(
    get_contract_account,
    get_starknet_address,
    starknet: StarknetContract,
    expected_post_state,
):
    for address, post_state in expected_post_state.items():
        evm_address = int(address, 16)
        starknet_address = get_starknet_address(evm_address)
        contract = get_contract_account(starknet_address)

        actual_nonce = (
            # For EOA's, nonces are mapped to system level nonce.
            await starknet.state.state.get_nonce_at(starknet_address)
            if is_account_eoa(expected_post_state)
            # For evm contracts, nonces are managed by Kakarot as contract state.
            else await starknet.state.state.get_storage_at(
                starknet_address, get_storage_var_address("nonce")
            )
        )

        expected_nonce = int(post_state["nonce"], 16)

        assert (
            actual_nonce == expected_nonce
        ), f"Contract {address=}: {expected_nonce=} is not {actual_nonce=}"

    for key, expected_storage in post_state["storage"].items():
        key = int_to_uint256(int(key, 16))
        expected_storage = int_to_uint256(int(expected_storage, 16))
        actual_storage = (await contract.storage(key).call()).result.value

        assert (
            actual_storage == expected_storage
        ), f"Contract {address}: expected storage={display_storage(expected_storage)} is not actual_storage={display_storage(actual_storage)}"
