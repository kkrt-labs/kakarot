from typing import Callable

import pytest
from web3 import Web3

MOCK_COUNTER_ADDRESS = Web3.toChecksumAddress("0x" + hex(42)[2:].rjust(40, "0"))


@pytest.mark.asyncio
@pytest.mark.IntegrationTestContract
class TestPlainOpcodes:
    class TestCall:
        async def test_staticcall_should_not_increase_counter(
            self,
            deploy_solidity_contract: Callable,
            addresses,
        ):
            counter = await deploy_solidity_contract(
                "Counter", "Counter", caller_address=addresses[1]["int"]
            )
            counter_address = Web3.toChecksumAddress(
                "0x"
                + hex(
                    counter.contract_account.deploy_call_info.result.evm_contract_address
                )[2:].rjust(40, "0")
            )
            integration_contract = await deploy_solidity_contract(
                "PlainOpcodes",
                "PlainOpcodes",
                counter_address,
                caller_address=addresses[1]["int"],
            )

            with pytest.raises(Exception) as e:
                await integration_contract.opcodeStaticCall2(
                    caller_address=addresses[1]["int"]
                )
                message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
                assert message == "Kakarot: StateModificationError"

        async def test_should_return_counter_count_and_increase_it(
            self,
            deploy_solidity_contract: Callable,
            addresses,
        ):
            counter = await deploy_solidity_contract(
                "Counter", "Counter", caller_address=addresses[1]["int"]
            )
            counter_address = Web3.toChecksumAddress(
                "0x"
                + hex(
                    counter.contract_account.deploy_call_info.result.evm_contract_address
                )[2:].rjust(40, "0")
            )
            integration_contract = await deploy_solidity_contract(
                "PlainOpcodes",
                "PlainOpcodes",
                counter_address,
                caller_address=addresses[1]["int"],
            )

            count = await integration_contract.opcodeStaticCall()
            assert count == 0
            await integration_contract.opcodeCall(caller_address=addresses[1]["int"])
            count = await integration_contract.opcodeStaticCall()
            assert count == 1

    class TestBlockhash:
        async def test_should_return_blockhash(
            self,
            deploy_solidity_contract: Callable,
            addresses,
            blockhashes,
        ):
            integration_contract = await deploy_solidity_contract(
                "PlainOpcodes",
                "PlainOpcodes",
                MOCK_COUNTER_ADDRESS,  # opcode doesn't need this deploy
                caller_address=addresses[1]["int"],
            )

            block_number = max(blockhashes["last_256_blocks"].keys())
            blockhash = await integration_contract.opcodeBlockHash(int(block_number))

            assert (
                int.from_bytes(blockhash, byteorder="big")
                == blockhashes["last_256_blocks"][block_number]
            )

            blockhash_invalid_number = await integration_contract.opcodeBlockHash(1)

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

    class TestAddress:
        async def test_should_return_self_address(
            self,
            deploy_solidity_contract: Callable,
            addresses,
        ):
            integration_contract = await deploy_solidity_contract(
                "PlainOpcodes",
                "PlainOpcodes",
                MOCK_COUNTER_ADDRESS,  # opcode doesn't need this deploy
                caller_address=addresses[1]["int"],
            )

            evm_contract_address = await integration_contract.opcodeAddress()

            assert (
                integration_contract.contract_account.deploy_call_info.result.evm_contract_address
                == int(evm_contract_address, 16)
            )
