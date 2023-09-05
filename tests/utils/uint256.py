from typing import Tuple
from starkware.starknet.public.abi import get_storage_var_address


def int_to_uint256(value):
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return low, high


def uint256_to_int(low, high):
    return low + high * 2**128


def hex_string_to_uint256(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")

    # Remove '0x' prefix if present
    if h[:2] == "0x":
        h = h[2:]

    # Convert hex string directly to an integer
    value = int(h, 16)

    # Convert integer to uint256
    return int_to_uint256(value)


def get_uint256_storage_var_keys(var_name: str, *args) -> Tuple[int, int]:
    low_key = get_storage_var_address(var_name, *args)
    return (low_key, low_key + 1)
