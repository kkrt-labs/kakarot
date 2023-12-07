import random
from textwrap import wrap
from typing import List, Tuple, Union

import rlp
from eth_abi import encode
from eth_account import Account
from eth_keys import keys
from eth_keys.datatypes import PrivateKey
from eth_utils import decode_hex, keccak, to_checksum_address
from hexbytes import HexBytes

from tests.utils.constants import CHAIN_ID

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
    mem = [0] * result.memory_words_len * 32
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


# The following helpers are translated from https://github.com/Uniswap/v2-core/blob/master/test/shared/utilities.ts
def expand_to_18_decimals(n: int) -> int:
    return n * 10**18


def get_domain_separator(name: str, token_address: str) -> bytes:
    return keccak(
        encode(
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


def get_create_address(sender_address: Union[int, str], nonce: int) -> str:
    """
    See [CREATE](https://www.evm.codes/#f0).
    """
    return to_checksum_address(
        keccak(rlp.encode([decode_hex(to_checksum_address(sender_address)), nonce]))[
            -20:
        ]
    )


def get_create2_address(
    sender_address: Union[int, str], salt: int, initialization_code: bytes
) -> str:
    """
    See [CREATE2](https://www.evm.codes/#f5).
    """
    return to_checksum_address(
        keccak(
            b"\xff"
            + decode_hex(to_checksum_address(sender_address))
            + salt.to_bytes(32, "big")
            + keccak(initialization_code)
        )[-20:]
    )


def get_approval_digest(
    token_name: str, token_address: str, approve: dict, nonce: int, deadline: int
) -> bytes:
    domain_separator = get_domain_separator(token_name, token_address)
    return keccak(
        b"\x19"
        + b"\x01"
        + domain_separator
        + keccak(
            encode(
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


def private_key_from_hex(hex_key: str):
    return keys.PrivateKey(bytes.fromhex(hex_key))


def generate_random_private_key(seed=0):
    random.seed(seed)
    return keys.PrivateKey(int.to_bytes(random.getrandbits(256), 32, "big"))


def generate_random_evm_address(seed=0):
    random.seed(seed)
    return to_checksum_address(hex(random.getrandbits(160)))


def ec_sign(
    digest: bytes, owner_private_key: keys.PrivateKey
) -> Tuple[int, bytes, bytes]:
    signature = owner_private_key.sign_msg_hash(digest)
    return (
        signature.v + 27,
        int.to_bytes(signature.r, 32, "big"),
        int.to_bytes(signature.s, 32, "big"),
    )


def get_multicall_from_evm_txs(
    evm_txs: list, private_key: PrivateKey
) -> Tuple[list, bytes, list]:
    calls = []
    calldata = b""
    expected_result = []
    for transaction in evm_txs:
        tx = Account.sign_transaction(transaction, private_key)["rawTransaction"]
        calls += [
            (
                0x0,  # to
                0x0,  # selector
                len(calldata),  # data_offset
                len(tx),  # data_len
            )
        ]
        calldata += tx

        # See ./tests/src/kakarot/accounts/eoa/mock_kakarot.cairo
        expected_result += [
            int(private_key.public_key.to_address(), 16),  # origin
            int.from_bytes(HexBytes(transaction["to"]), "big"),  # to
            transaction["gas"],  # gas_limit
            transaction.get("gasPrice", transaction.get("maxFeePerGas")),  # gas_price
            transaction["value"],  # value
            len(
                bytes.fromhex(transaction.get("data", "").replace("0x", ""))
            ),  # data_len
            *list(bytes.fromhex(transaction.get("data", "").replace("0x", ""))),  # data
        ]

    return (calls, calldata, expected_result)


def pack_64_bits_little(input: List[int]):
    return sum([x * 256**i for (i, x) in enumerate(input)])
