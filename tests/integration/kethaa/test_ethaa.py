import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), "../"))
import pytest
import web3
from eth_account._utils.legacy_transactions import (
    serializable_unsigned_transaction_from_dict,
)
from eth_keys import keys
from starkware.starknet.testing.starknet import Starknet
from starkware.starkware_utils.error_handling import StarkException

from tests.utils.bits import combine_ints, to_uint
from tests.utils.signer import BaseSigner, MockEthSigner

txdict = dict(
    nonce=1,
    chainId=9001,
    maxFeePerGas=1000,
    maxPriorityFeePerGas=667667,
    gas=999999999,
    to=bytes.fromhex("95222290dd7278aa3ddd389cc1e1d165cc4bafe5"),
    value=10000000000000000,
    data=b"",
)


@pytest.mark.asyncio
async def test_address_compute(setup_kethaa):
    starknet = await Starknet.empty()
    (deployer, account, private_key, evm_address) = setup_kethaa

    call_info = await deployer.compute_starknet_address(evm_address=evm_address).call()

    assert call_info.result.contract_address == account.contract_address

    call_info = await account.get_eth_address().call()

    assert call_info.result.eth_address == evm_address


@pytest.mark.asyncio
async def test_eth_aa_signature(setup_kethaa):
    starknet = await Starknet.empty()
    (deployer, account, private_key, evm_address) = setup_kethaa
    evm_eoa = web3.Account.from_key(keys.PrivateKey(private_key_bytes=private_key))
    raw_tx = evm_eoa.sign_transaction(txdict)
    txhash = serializable_unsigned_transaction_from_dict(txdict).hash()
    call_info = await account.is_valid_signature(
        [*to_uint(web3.Web3.toInt(txhash))],
        [raw_tx.v, *to_uint(raw_tx.r), *to_uint(raw_tx.s)],
    ).call()
    assert call_info.result.is_valid == True
    with pytest.raises(StarkException):
        # test invalid signature
        await account.is_valid_signature(
            [*to_uint(web3.Web3.toInt(os.urandom(32)))],
            [raw_tx.v, *to_uint(raw_tx.r), *to_uint(raw_tx.s)],
        ).call()


@pytest.mark.asyncio
async def test_execute(setup_kethaa):
    starknet = await Starknet.empty()

    (deployer, account, private_key, evm_address) = setup_kethaa
    eth_account = MockEthSigner(private_key=private_key)

    evm_eoa = web3.Account.from_key(private_key)
    raw_tx = evm_eoa.sign_transaction(txdict)

    await eth_account.send_transaction(
        account,
        1409719322379134103315153819531084269022823759702923787575976457644523059131,
        "execute_at_address",
        raw_tx.rawTransaction,
    )

    with pytest.raises(StarkException):
        # incorect selector
        await eth_account.send_transaction(
            account,
            1409719322379134103315153819531084269022823759702923787575976457644523059131,
            "incorrect_selector",
            raw_tx.rawTransaction,
        )
        # incorect target contract
        await eth_account.send_transaction(
            account,
            1409719322379134103315153819531084739497123759702923787575976457644523059131,
            "execute_at_address",
            raw_tx.rawTransaction,
        )
        # incorect signature
        evm_eoa = web3.Account.from_key(os.urandom(32))
        raw_tx = evm_eoa.sign_transaction(txdict)
        await eth_account.send_transaction(
            account,
            1409719322379134103315153819531084269022823759702923787575976457644523059131,
            "incorrect_selector",
            raw_tx.rawTransaction,
        )
