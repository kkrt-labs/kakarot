from tests.utils.uint256 import uint256_to_int


def display_storage(uint256_tuple):
    return hex(uint256_to_int(*uint256_tuple))


def is_account_eoa(state: dict) -> bool:
    return state.get("code") in [None, "0x"] and not state.get("storage")
