from enum import IntEnum
from time import time

from kakarot_scripts.constants import BLOCK_GAS_LIMIT

BLOCK_GAS_LIMIT = BLOCK_GAS_LIMIT

CHAIN_ID = int.from_bytes(b"KKRT", "big")  # KKRT (0x4b4b5254) in ASCII
BIG_CHAIN_ID = int.from_bytes(b"SN_SEPOLIA", "big")

# Class hash of the cairo1 helpers
CAIRO1_HELPERS_CLASS_HASH = 0xDEADBEEFABDE1E11A5

# Amount of funds to pre-fund the account with
PRE_FUND_AMOUNT = int(1e17)  # 0.01 ETH

# Account balance is the amount of funds that the account has after being deployed
ACCOUNT_BALANCE = PRE_FUND_AMOUNT

# Coinbase address is the address of the sequencer
MOCK_COINBASE_ADDRESS = (
    0x388CA486B82E20CC81965D056B4CDCAACDFFE0CF08E20ED8BA10EA97A487004
)

# STACK
STACK_MAX_DEPTH = 1024

# GAS METERING
TRANSACTION_INTRINSIC_GAS_COST = 21_000

# TRANSACTION
# TODO: handle tx gas limit properly and remove this constant
# Temporarily set tx gas limit to 20M gas (= block gas limit)
TRANSACTION_GAS_LIMIT = BLOCK_GAS_LIMIT

# PRECOMPILES
LAST_PRECOMPILE_ADDRESS = 0x0A

MAX_INT = 2**256 - 1

ZERO_ADDRESS = "0x" + 40 * "0"

BLOCK_NUMBER = 0x42
BLOCK_TIMESTAMP = int(time())

# Taken from eth_account.account.Account.sign_transaction docstring
# https://eth-account.readthedocs.io/en/stable/eth_account.html?highlight=sign_transaction#eth_account.account.Account.sign_transaction
TRANSACTIONS = [
    {
        # Note that the address must be in checksum format or native bytes:
        "to": "0xF0109fC8DF283027b6285cc889F5aA624EaC1F55",
        "value": 1_000_000_000,
        "gas": 2_000_000,
        "gasPrice": 234567897654321,
        "nonce": 0,
        "chainId": CHAIN_ID,
        "data": b"",
    },
    {
        "type": 1,
        "gas": 100_000,
        "gasPrice": 1_000_000_000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "0x09616C3d61b3331fc4109a9E41a8BDB7d9776609",
        "value": 0x5AF3107A4000,
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000001",
                "storageKeys": (
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                ),
            },
        ),
        "chainId": CHAIN_ID,
    },
    # Access list with two addresses
    {
        "type": 1,
        "gas": 100_000,
        "gasPrice": 1_000_000_000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "0x09616C3d61b3331fc4109a9E41a8BDB7d9776609",
        "value": 0x5AF3107A4000,
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000001",
                "storageKeys": (
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                ),
            },
            {
                "address": "0x0000000000000000000000000000000000000002",
                "storageKeys": (
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                    "0x0200000000000000000000000000000000000000000000000000000000000000",
                ),
            },
            {
                "address": "0x0000000000000000000000000000000000000003",
                "storageKeys": [],
            },
        ),
        "chainId": CHAIN_ID,
    },
    {
        "type": 2,
        "gas": 100_000,
        "maxFeePerGas": 2_000_000_000,
        "maxPriorityFeePerGas": 2_000_000_000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "0x09616C3d61b3331fc4109a9E41a8BDB7d9776609",
        "value": 0x5AF3107A4000,
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000001",
                "storageKeys": (
                    "0x0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF",
                ),
            },
        ),
        "chainId": CHAIN_ID,
    },
    # eip1559 with storage keys in accesslist and 2 addresses, including one duplication
    {
        "type": 2,
        "gas": 100_000,
        "maxFeePerGas": 2_000_000_000,
        "maxPriorityFeePerGas": 2_000_000_000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "0x09616C3d61b3331fc4109a9E41a8BDB7d9776609",
        "value": 0x5AF3107A4000,
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000101",
                "storageKeys": [
                    "0x0000000000000000000000000000000000000000000000000000000000000000"
                ],
            },
            {
                "address": "0x0000000000000000000000000000000000000101",
                "storageKeys": [
                    "0x0000000000000000000000000000000000000000000000000000000000000001"
                ],
            },
        ),
        "chainId": CHAIN_ID,
    },
    {
        "type": 2,
        "gas": 100_000,
        "maxFeePerGas": 2_000_000_000,
        "maxPriorityFeePerGas": 2_000_000_000,
        "data": "0x616263646566",
        "nonce": 34,
        "to": "",
        "value": 0x00,
        "accessList": (
            {
                "address": "0x0000000000000000000000000000000000000001",
                "storageKeys": (
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                ),
            },
        ),
        "chainId": CHAIN_ID,
    },
    # Deploy counter tx
    {
        "type": 2,
        "value": 0,
        "gas": 21000,
        "maxFeePerGas": 10_000_000_002,
        "maxPriorityFeePerGas": 10_000_000_000,
        "chainId": CHAIN_ID,
        "nonce": 4,
        "data": "0x608060405234801561001057600080fd5b506000805561023c806100246000396000f3fe608060405234801561001057600080fd5b50600436106100625760003560e01c806306661abd14610067578063371303c0146100825780637c507cbd1461008c578063b3bcfa8214610094578063d826f88f1461009c578063f0707ea9146100a5575b600080fd5b61007060005481565b60405190815260200160405180910390f35b61008a6100ad565b005b61008a6100c6565b61008a610106565b61008a60008055565b61008a610139565b60016000808282546100bf919061017c565b9091555050565b60008054116100f05760405162461bcd60e51b81526004016100e790610195565b60405180910390fd5b6000805490806100ff836101dc565b9190505550565b60008054116101275760405162461bcd60e51b81526004016100e790610195565b60016000808282546100bf91906101f3565b600080541161015a5760405162461bcd60e51b81526004016100e790610195565b60008054600019019055565b634e487b7160e01b600052601160045260246000fd5b8082018082111561018f5761018f610166565b92915050565b60208082526027908201527f636f756e742073686f756c64206265207374726963746c7920677265617465726040820152660207468616e20360cc1b606082015260800190565b6000816101eb576101eb610166565b506000190190565b8181038181111561018f5761018f61016656fea2646970667358221220d15685bf0e446bfa459abadf9c47cf4c3367c09c39dccb9b38f2106bb7ffca2a64736f6c63430008110033",
        "to": b"",
    },
]


class Opcodes(IntEnum):
    STOP = 0x00
    ADD = 0x01
    MUL = 0x02
    SUB = 0x03
    DIV = 0x04
    SDIV = 0x05
    MOD = 0x06
    SMOD = 0x07
    ADDMOD = 0x08
    MULMOD = 0x09
    EXP = 0x0A
    SIGNEXTEND = 0x0B
    LT = 0x10
    GT = 0x11
    SLT = 0x12
    SGT = 0x13
    EQ = 0x14
    ISZERO = 0x15
    AND = 0x16
    OR = 0x17
    XOR = 0x18
    NOT = 0x19
    BYTE = 0x1A
    SHL = 0x1B
    SHR = 0x1C
    SAR = 0x1D
    KECCAK256 = 0x20
    ADDRESS = 0x30
    BALANCE = 0x31
    ORIGIN = 0x32
    CALLER = 0x33
    CALLVALUE = 0x34
    CALLDATALOAD = 0x35
    CALLDATASIZE = 0x36
    CALLDATACOPY = 0x37
    CODESIZE = 0x38
    CODECOPY = 0x39
    GASPRICE = 0x3A
    EXTCODESIZE = 0x3B
    EXTCODECOPY = 0x3C
    RETURNDATASIZE = 0x3D
    RETURNDATACOPY = 0x3E
    EXTCODEHASH = 0x3F
    BLOCKHASH = 0x40
    COINBASE = 0x41
    TIMESTAMP = 0x42
    NUMBER = 0x43
    PREVRANDAO = 0x44
    GASLIMIT = 0x45
    CHAINID = 0x46
    SELFBALANCE = 0x47
    BASEFEE = 0x48
    BLOBHASH = 0x49
    BLOBBASEFEE = 0x4A
    POP = 0x50
    MLOAD = 0x51
    MSTORE = 0x52
    MSTORE8 = 0x53
    SLOAD = 0x54
    SSTORE = 0x55
    JUMP = 0x56
    JUMPI = 0x57
    PC = 0x58
    MSIZE = 0x59
    GAS = 0x5A
    JUMPDEST = 0x5B
    TLOAD = 0x5C
    TSTORE = 0x5D
    PUSH0 = 0x5F
    PUSH1 = 0x60
    PUSH2 = 0x61
    PUSH3 = 0x62
    PUSH4 = 0x63
    PUSH5 = 0x64
    PUSH6 = 0x65
    PUSH7 = 0x66
    PUSH8 = 0x67
    PUSH9 = 0x68
    PUSH10 = 0x69
    PUSH11 = 0x6A
    PUSH12 = 0x6B
    PUSH13 = 0x6C
    PUSH14 = 0x6D
    PUSH15 = 0x6E
    PUSH16 = 0x6F
    PUSH17 = 0x70
    PUSH18 = 0x71
    PUSH19 = 0x72
    PUSH20 = 0x73
    PUSH21 = 0x74
    PUSH22 = 0x75
    PUSH23 = 0x76
    PUSH24 = 0x77
    PUSH25 = 0x78
    PUSH26 = 0x79
    PUSH27 = 0x7A
    PUSH28 = 0x7B
    PUSH29 = 0x7C
    PUSH30 = 0x7D
    PUSH31 = 0x7E
    PUSH32 = 0x7F
    DUP1 = 0x80
    DUP2 = 0x81
    DUP3 = 0x82
    DUP4 = 0x83
    DUP5 = 0x84
    DUP6 = 0x85
    DUP7 = 0x86
    DUP8 = 0x87
    DUP9 = 0x88
    DUP10 = 0x89
    DUP11 = 0x8A
    DUP12 = 0x8B
    DUP13 = 0x8C
    DUP14 = 0x8D
    DUP15 = 0x8E
    DUP16 = 0x8F
    SWAP1 = 0x90
    SWAP2 = 0x91
    SWAP3 = 0x92
    SWAP4 = 0x93
    SWAP5 = 0x94
    SWAP6 = 0x95
    SWAP7 = 0x96
    SWAP8 = 0x97
    SWAP9 = 0x98
    SWAP10 = 0x99
    SWAP11 = 0x9A
    SWAP12 = 0x9B
    SWAP13 = 0x9C
    SWAP14 = 0x9D
    SWAP15 = 0x9E
    SWAP16 = 0x9F
    LOG0 = 0xA0
    LOG1 = 0xA1
    LOG2 = 0xA2
    LOG3 = 0xA3
    LOG4 = 0xA4
    CREATE = 0xF0
    CALL = 0xF1
    CALLCODE = 0xF2
    RETURN = 0xF3
    DELEGATECALL = 0xF4
    CREATE2 = 0xF5
    STATICCALL = 0xFA
    REVERT = 0xFD
    INVALID = 0xFE
    SELFDESTRUCT = 0xFF
