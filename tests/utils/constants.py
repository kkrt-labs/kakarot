CHAIN_ID = 1263227476  # KKRT (0x4b4b5254) in ASCII

# Deployment fee to be returned to the deployer of the account
DEPLOY_FEE = int(1e15)  # 0.001 ETH

# Amount of funds to pre-fund the account with
PRE_FUND_AMOUNT = int(1e17)  # 0.01 ETH

# Account balance is the amount of funds that the account has after being deployed
ACCOUNT_BALANCE = PRE_FUND_AMOUNT - DEPLOY_FEE

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
