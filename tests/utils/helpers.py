import random
from collections import defaultdict
from textwrap import wrap
from typing import List, Tuple, Union

import rlp
from eth_abi import encode
from eth_account._utils.transaction_utils import transaction_rpc_to_rlp_structure
from eth_account._utils.typed_transactions import TypedTransaction
from eth_keys import keys
from eth_utils import decode_hex, keccak, to_checksum_address
from starkware.starknet.public.abi import get_storage_var_address

from kakarot_scripts.constants import NETWORK
from tests.utils.uint256 import int_to_uint256

PERMIT_TYPEHASH = keccak(
    text="Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
)


def rlp_encode_signed_data(tx: dict) -> bytes:
    if "type" in tx:
        typed_transaction = TypedTransaction.from_dict(tx)

        sanitized_transaction = transaction_rpc_to_rlp_structure(
            typed_transaction.transaction.dictionary
        )

        # RPC-structured transaction to rlp-structured transaction
        rlp_serializer = (
            typed_transaction.transaction.__class__._unsigned_transaction_serializer
        )
        encoded_unsigned_tx = [
            typed_transaction.transaction_type,
            *rlp.encode(rlp_serializer.from_dict(sanitized_transaction)),
        ]

        return encoded_unsigned_tx
    else:
        legacy_tx = [
            tx["nonce"],
            tx["gasPrice"],
            tx["gas"],
            int(tx["to"], 16),
            tx["value"],
            tx["data"],
            tx["chainId"],
            0,
            0,
        ]
        encoded_unsigned_tx = rlp.encode(legacy_tx)

        return encoded_unsigned_tx


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
        v = result.memory_accesses[i + 2]  # Final value.
        mem[k * 16 : k * 16 + 16] = bytes.fromhex(f"{v:032x}")
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
                NETWORK["chain_id"],
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
    return to_checksum_address(f"{random.getrandbits(160):040x}")


def ec_sign(
    digest: bytes, owner_private_key: keys.PrivateKey
) -> Tuple[int, bytes, bytes]:
    signature = owner_private_key.sign_msg_hash(digest)
    return (
        signature.v + 27,
        int.to_bytes(signature.r, 32, "big"),
        int.to_bytes(signature.s, 32, "big"),
    )


def pack_64_bits_little(input: List[int]):
    return sum([x * 256**i for (i, x) in enumerate(input)])


def flatten(data):
    result = []

    def _flatten(item):
        if isinstance(item, list):
            for sub_item in item:
                _flatten(sub_item)
        else:
            result.extend(item)

    _flatten(data)
    return result


def flatten_tx_access_list(access_list):
    """
    Transform the access list from the transaction dict into a flattened list of
    [address, storage_keys, ...].
    """
    result = []
    for item in access_list:
        result.append(int(item["address"], 16))
        result.append(len(item["storageKeys"]))
        for key in item["storageKeys"]:
            result.extend(int_to_uint256(int(key, 16)))
    return result


def merge_access_list(access_list):
    """
    Merge all entries of the access list to get one entry per account with all its storage keys.
    """
    merged_list = defaultdict(set)
    for access in access_list:
        merged_list[access["address"]] = merged_list[access["address"]].union(
            {
                get_storage_var_address(
                    "Account_storage", *int_to_uint256(int(key, 16))
                )
                for key in access["storageKeys"]
            }
        )
    return merged_list


def pack_into_u64_words(bytecode):
    bytes8_little_endian = [
        int.from_bytes(bytes(bytecode[i : i + 8]), byteorder="little")
        for i in range(0, len(bytecode), 8)
    ]

    last_word_bytes_used = len(bytecode) % 8
    if last_word_bytes_used == 0:
        last_word = 0
        full_words = bytes8_little_endian
    else:
        last_word = bytes8_little_endian[-1]
        full_words = bytes8_little_endian[:-1]

    return len(full_words), full_words, last_word, last_word_bytes_used
