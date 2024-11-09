import pytest
import pytest_asyncio
from eth_abi import encode
from eth_utils import keccak
from eth_utils.address import to_checksum_address
from web3.contract import Contract as Web3Contract

from kakarot_scripts.utils.kakarot import (
    deploy,
    eth_balance_of,
    eth_send_transaction,
    fund_address,
)
from kakarot_scripts.utils.starknet import call_contract
from tests.utils.errors import evm_error


@pytest_asyncio.fixture(scope="package")
async def coinbase(owner):
    kakarot_native_token = (
        await call_contract("kakarot", "get_native_token")
    ).native_token_address
    return await deploy(
        "Kakarot", "Coinbase", kakarot_native_token, caller_eoa=owner.starknet_contract
    )


@pytest.mark.asyncio(scope="package")
class TestCoinbase:
    class TestWithdrawal:
        async def test_should_withdraw_all_eth(self, coinbase, owner):
            await fund_address(coinbase.address, 0.001)
            balance_coinbase_prev = await eth_balance_of(coinbase.address)
            balance_owner_prev = await eth_balance_of(owner.address)
            tx = await coinbase.withdraw(owner.starknet_contract.address)
            balance_coinbase = await eth_balance_of(coinbase.address)
            balance_owner = await eth_balance_of(owner.address)
            assert balance_coinbase_prev > 0
            assert balance_coinbase == 0
            assert balance_owner - balance_owner_prev + tx["gas_used"] == 0.001e18

        async def test_should_revert_when_not_owner(self, coinbase, other):
            error = keccak(b"OwnableUnauthorizedAccount(address)")[:4] + encode(
                ["address"], [other.address]
            )
            with evm_error(error):
                await coinbase.withdraw(0xDEAD, caller_eoa=other.starknet_contract)

    class TestReceive:
        async def test_should_receive_ether(self, coinbase: Web3Contract, owner):
            amount = 0.001
            amount_wei = int(amount * 1e18)
            await fund_address(owner.address, 0.001)
            balance_coinbase_prev = await eth_balance_of(coinbase.address)
            await eth_send_transaction(
                coinbase.address,
                data=b"",
                value=amount_wei,
                caller_eoa=owner.starknet_contract,
            )
            balance_coinbase_after = await eth_balance_of(coinbase.address)
            assert balance_coinbase_after == balance_coinbase_prev + amount_wei

    class TestTransferOwnership:

        async def test_should_transfer_ownership(self, coinbase, owner, other):
            # initiate transfer process
            await coinbase.transferOwnership(other.address)
            assert await coinbase.pendingOwner() == other.address
            assert await coinbase.owner() == owner.address
            # accept the transfer
            await coinbase.acceptOwnership(caller_eoa=other.starknet_contract)
            ZERO_ADDRESS = to_checksum_address(f"0x{0:040x}")
            assert await coinbase.pendingOwner() == ZERO_ADDRESS
            assert await coinbase.owner() == other.address
            # teardown
            await coinbase.transferOwnership(
                owner.address, caller_eoa=other.starknet_contract
            )
            await coinbase.acceptOwnership(caller_eoa=owner.starknet_contract)

        async def test_should_revert_when_not_owner(self, coinbase, other):
            error = keccak(b"OwnableUnauthorizedAccount(address)")[:4] + encode(
                ["address"], [other.address]
            )
            with evm_error(error):
                await coinbase.transferOwnership(
                    other.address, caller_eoa=other.starknet_contract
                )
