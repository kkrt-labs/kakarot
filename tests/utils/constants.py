CHAIN_ID = 1263227476  # KKRT (0x4b4b5254) in ASCII

# Coinbase address is the address of the sequencer
MOCK_COINBASE_ADDRESS = (
    0x388CA486B82E20CC81965D056B4CDCAACDFFE0CF08E20ED8BA10EA97A487004
)
# Hardcode block gas limit to 20M
BLOCK_GAS_LIMIT = 20_000_000

# STACK
STACK_MAX_DEPTH = 1024

# GAS METERING
TRANSACTION_INTRINSIC_GAS_COST = 21_000

# TRANSACTION
# TODO: handle tx gas limit properly and remove this constant
# Temporarily set tx gas limit to 1M gas
TRANSACTION_GAS_LIMIT = 1_000_000

# PRECOMPILES
LAST_PRECOMPILE_ADDRESS = 0x09

MAX_INT = 2**256 - 1

ZERO_ADDRESS = "0x" + 40 * "0"

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
                    "0x0100000000000000000000000000000000000000000000000000000000000000",
                ),
            },
        ),
        "chainId": CHAIN_ID,
    },
]
