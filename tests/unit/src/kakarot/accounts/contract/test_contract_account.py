import random

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import StarknetContract
from starkware.starknet.testing.starknet import Starknet

from tests.utils.errors import kakarot_error
from tests.utils.reporting import traceit

random.seed(0)


@pytest_asyncio.fixture(scope="module")
async def contract_account(starknet: Starknet, kakarot: StarknetContract):
    contract = await starknet.deploy(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
    )
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

        async def test_should_give_inifinite_allowance_to_kakarot(
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

    """
    class TestNonce:
        async def test_should_increment_nonce(
            self, contract_account: StarknetContract, kakarot
        ):
            # Get current contract account nonce
            initial_nonce = await contract_account.get_nonce.call()

            # Store bytecode that includes CREATE opcode
            contract_account.write_bytecode([0]).execute(
                caller_address=kakarot.contract_address
            )

            # Run bytecode
            kakarot.execute_at_address(nonce: felt, bytecode_len: felt, bytecode: felt*)

            # Get new nonce
            assert initial_nonce == await contract_account.get_nonce().call()


        async def test_should_influence_address_generation(
            self, contract_account: StarknetContract, kakarot
        ):
            x = 1
    """
