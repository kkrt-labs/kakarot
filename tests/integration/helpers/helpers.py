import random
from textwrap import wrap
from typing import Tuple

from eth_abi import encode_abi
from eth_keys import keys
from eth_utils import decode_hex, keccak, to_checksum_address

from tests.integration.helpers.constants import CHAIN_ID

PERMIT_TYPEHASH = keccak(
    text="Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
)


def hex_string_to_bytes_array(h: str):
    if len(h) % 2 != 0:
        raise ValueError(f"Provided string has an odd length {len(h)}")
    if h[:2] == "0x":
        h = h[2:]
    return [int(b, 16) for b in wrap(h, 2)]


def extract_memory_from_execute(result):
    mem = [0] * result.memory_bytes_len
    for i in range(0, len(result.memory_accesses), 3):
        k = result.memory_accesses[i]  # Word index.
        assert result.memory_accesses[i + 1] == 0  # Initial value.
        v = result.memory_accesses[i + 2]  # Final value.
        for j in range(16):
            if k * 16 + 15 - j < len(mem):
                mem[k * 16 + 15 - j] = v % 256
            else:
                assert v == 0
            v //= 256
    return mem


def extract_stack_from_execute(result):
    stack = [0] * int(result.stack_len / 2)
    for i in range(0, result.stack_len * 3, 6):
        k = result.stack_accesses[i]  # Word index.
        index = int(k / 2)
        assert result.stack_accesses[i + 1] == 0  # Initial value.
        high = result.stack_accesses[i + 2]  # Final value.
        assert result.stack_accesses[i + 4] == 0  # Initial value.
        low = result.stack_accesses[i + 5]  # Final value.
        stack[index] = 2**128 * high + low

    return stack


def int_to_uint256(value):
    low = value & ((1 << 128) - 1)
    high = value >> 128
    return low, high


# The following helpers are translated from https://github.com/Uniswap/v2-core/blob/master/test/shared/utilities.ts
def expand_to_18_decimals(n: int) -> int:
    return n * 10**18


def get_domain_separator(name: str, token_address: str) -> bytes:
    return keccak(
        encode_abi(
            ["bytes32", "bytes32", "bytes32", "uint256", "address"],
            [
                keccak(
                    text="EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak(text=name),
                keccak(text="1"),
                CHAIN_ID,
                token_address,
            ],
        )
    )


def get_create2_address(
    factory_address: str, token_a: str, token_b: str, bytecode: bytes
) -> str:
    token_0, token_1 = sorted([token_a, token_b])
    create2_inputs = [
        b"\xff",
        decode_hex(factory_address),
        keccak(
            encode_abi(
                ["address", "address"],
                [token_0, token_1],
            )
        ),
        keccak(bytecode),
    ]
    sanitized_inputs = b"".join(create2_inputs[2:])
    return to_checksum_address(keccak(sanitized_inputs)[-40:])


def get_approval_digest(
    token_name: str, token_address: str, approve: dict, nonce: int, deadline: int
) -> bytes:
    domain_separator = get_domain_separator(token_name, token_address)
    return keccak(
        b"\x19"
        + b"\x01"
        + domain_separator
        + keccak(
            encode_abi(
                [
                    "bytes32",
                    "address",
                    "address",
                    "uint256",
                    "uint256",
                    "uint256",
                ],
                [
                    PERMIT_TYPEHASH,
                    approve["owner"],
                    approve["spender"],
                    approve["value"],
                    nonce,
                    deadline,
                ],
            )
        ),
    )


def encode_price(reserve_0: int, reserve_1: int) -> list:
    return [
        reserve_1 * 2**112 // reserve_0,
        reserve_0 * 2**112 // reserve_1,
    ]


def generate_random_private_key():
    return keys.PrivateKey(int.to_bytes(random.getrandbits(256), 32, "big"))


def ec_sign(
    digest: bytes, owner_private_key: keys.PrivateKey
) -> Tuple[int, bytes, bytes]:
    signature = owner_private_key.sign_msg_hash(digest)
    return (
        signature.v + 27,
        bytes.fromhex(f"{signature.r:x}"),
        bytes.fromhex(f"{signature.s:x}"),
    )
