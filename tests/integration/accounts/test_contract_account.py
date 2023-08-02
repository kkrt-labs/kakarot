import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.accounts import fund_evm_address
from tests.utils.constants import DEPLOY_FEE
from tests.utils.errors import kakarot_error
from tests.utils.helpers import generate_random_evm_address
from tests.utils.reporting import traceit

random.seed(0)


@pytest_asyncio.fixture(scope="module")
async def contract_account(starknet: Starknet, kakarot: StarknetContract):
    class_hash = await starknet.deprecated_declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
    contract = await starknet.deploy(class_hash=class_hash.class_hash)
    await contract.initialize(kakarot.contract_address, 1).execute(
        caller_address=kakarot.contract_address
    )
    return contract


@pytest.mark.asyncio
class TestContractAccount:
    @pytest.mark.parametrize("bytecode_len", [0, 15, 16, 17, 30, 31, 32, 33])
    async def test_should_store_code(
        self, contract_account: StarknetContract, bytecode_len, kakarot
    ):
        bytecode = [random.randint(0, 255) for _ in range(bytecode_len)]

        with traceit.context("contract_account"):
            await contract_account.write_bytecode(bytecode).execute(
                caller_address=kakarot.contract_address
            )
        stored_bytecode = (await contract_account.bytecode().call()).result.bytecode
        assert stored_bytecode == bytecode

    class TestInitialize:
        async def test_should_run_only_once(
            self, contract_account: StarknetContract, kakarot
        ):
            with kakarot_error():
                await contract_account.initialize(kakarot.contract_address, 1).execute(
                    caller_address=kakarot.contract_address
                )

        async def test_should_set_ownership(
            self, contract_account: StarknetContract, kakarot
        ):
            with kakarot_error():
                await contract_account.write_bytecode([0]).execute(caller_address=1)
            await contract_account.write_bytecode([0]).execute(
                caller_address=kakarot.contract_address
            )

        async def test_should_give_infinite_allowance_to_kakarot(
            self, contract_account: StarknetContract, kakarot, eth
        ):
            # Check that current allowance is MAX Uint256
            assert (
                str(
                    (
                        await eth.allowance(
                            contract_account.contract_address,
                            kakarot.contract_address,
                        ).call()
                    ).result.remaining
                )
                == "Uint256(low=340282366920938463463374607431768211455, high=340282366920938463463374607431768211455)"
            )
            # Test whether this actually results in having infinite allowance
            await eth.mint(contract_account.contract_address, (1000, 0)).execute(
                caller_address=2
            )
            await eth.transferFrom(
                contract_account.contract_address, 1, (1000, 0)
            ).execute(caller_address=kakarot.contract_address)
            assert (
                str(
                    (
                        await eth.allowance(
                            contract_account.contract_address,
                            kakarot.contract_address,
                        ).call()
                    ).result.remaining
                )
                == "Uint256(low=340282366920938463463374607431768211455, high=340282366920938463463374607431768211455)"
            )

        async def test_should_take_deployment_fees(self, kakarot, eth):
            evm_address = int(generate_random_evm_address(), 16)
            computed_starknet_address = (
                await kakarot.compute_starknet_address(evm_address).call()
            ).result[0]

            amount = 100000
            await fund_evm_address(evm_address, kakarot, eth, amount)

            await kakarot.deploy_externally_owned_account(evm_address).execute()

            # asserting that the balance of the account is the amount minus the deployment fee
            assert (
                await eth.balanceOf(computed_starknet_address).call()
            ).result.balance.low == (amount - DEPLOY_FEE)

            # asserting that the balance of the sequencer is the deployment fee
            assert (await eth.balanceOf(0).call()).result.balance.low == DEPLOY_FEE
