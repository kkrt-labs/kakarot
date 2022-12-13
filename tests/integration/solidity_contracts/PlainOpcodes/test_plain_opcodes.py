import json
from typing import Callable

import pytest
from web3 import Web3


@pytest.mark.asyncio
@pytest.mark.IntegrationTestContract
class TestPlainOpcodes:
    class TestAddress:
        async def test_should_return_self_address(
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

            evm_contract_address = await integration_contract.opcodeAddress()

            assert (
                integration_contract.contract_account.deploy_call_info.result.evm_contract_address
                == int(evm_contract_address, 16)
            )

    class TestBlockhash:
        async def test_should_return_blockhash(
            self,
            deploy_solidity_contract: Callable,
            addresses,
            blockhashes,
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

            blockhash = await integration_contract.opcodeBlockHash(503594)

            assert (
                int.from_bytes(blockhash, byteorder="big")
                == blockhashes["last_256_blocks"]["503594"]
            )

            blockhash_invalid_number = await integration_contract.opcodeBlockHash(1)

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

    class TestCall:
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
