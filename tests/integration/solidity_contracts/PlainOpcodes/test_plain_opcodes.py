import re

import pytest
from web3 import Web3

from tests.integration.helpers.helpers import (
    extract_memory_from_execute,
    hex_string_to_bytes_array,
)


@pytest.mark.asyncio
@pytest.mark.PlainOpcodes
@pytest.mark.usefixtures("starknet_snapshot")
class TestPlainOpcodes:
    class TestStaticCall:
        async def test_should_return_counter_count(self, counter, plain_opcodes):
            assert await plain_opcodes.opcodeStaticCall() == await counter.count()

        async def test_should_revert_when_trying_to_modify_state(
            self,
            plain_opcodes,
        ):
            with pytest.raises(Exception) as e:
                await plain_opcodes.opcodeStaticCall2()
            message = re.search(r"Error message: (.*)", e.value.message)[1]  # type: ignore
            assert message == "Kakarot: StateModificationError"

    class TestCall:
        async def test_should_increase_counter(
            self,
            counter,
            plain_opcodes,
            addresses,
        ):
            await plain_opcodes.opcodeCall(
                caller_address=addresses[1].starknet_contract.contract_address
            )
            assert await counter.count() == 1

    class TestBlockhash:
        async def test_should_return_blockhash_with_valid_block_number(
            self,
            plain_opcodes,
            blockhashes,
        ):
            block_number = max(blockhashes["last_256_blocks"].keys())
            blockhash = await plain_opcodes.opcodeBlockHash(int(block_number))

            assert (
                int.from_bytes(blockhash, byteorder="big")
                == blockhashes["last_256_blocks"][block_number]
            )

            blockhash_invalid_number = await plain_opcodes.opcodeBlockHash(1)

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

        async def test_should_return_0_with_invalid_block_number(
            self,
            plain_opcodes,
        ):
            blockhash_invalid_number = await plain_opcodes.opcodeBlockHash(1)

            assert int.from_bytes(blockhash_invalid_number, byteorder="big") == 0

    class TestAddress:
        async def test_should_return_self_address(
            self,
            plain_opcodes,
        ):
            evm_contract_address = await plain_opcodes.opcodeAddress()

            assert int(plain_opcodes.evm_contract_address, 16) == int(
                evm_contract_address, 16
            )

    class TestExtCodeCopy:
        async def test_extcodecopy_counter(self, counter, kakarot):
            evm_contract_address = (
                counter.contract_account.deploy_call_info.result.evm_contract_address
            )

            # instructions
            push1 = 60
            push20 = 73
            extcodecopy = "3c"

            # stack elements
            offset = 0
            size = 8
            dest_offset = 0

            byte_code = f"{push1}\
            {size:02x}\
            {push1}\
            {offset:02x}\
            {push1}\
            {dest_offset:02x}\
            {push20}\
            {evm_contract_address:x}\
            {extcodecopy}"

            res = await kakarot.execute(
                value=int(0),
                bytecode=hex_string_to_bytes_array(byte_code),
                calldata=hex_string_to_bytes_array(""),
            ).call(caller_address=1)

            expected_memory_result = hex_string_to_bytes_array(counter.bytecode.hex())
            memory_result = extract_memory_from_execute(res.result)

            assert (
                memory_result[dest_offset : size + dest_offset]
                == expected_memory_result[offset : offset + size]
            )

            # instructions
            push1 = 60
            push20 = 73
            extcodecopy = "3c"

            # stack elements
            offset = 10
            size = 9
            dest_offset = 100

            byte_code = f"{push1}\
            {size:02x}\
            {push1}\
            {offset:02x}\
            {push1}\
            {dest_offset:02x}\
            {push20}\
            {evm_contract_address:x}\
            {extcodecopy}"

            res = await kakarot.execute(
                value=int(0),
                bytecode=hex_string_to_bytes_array(byte_code),
                calldata=hex_string_to_bytes_array(""),
            ).call(caller_address=1)

            memory_result = extract_memory_from_execute(res.result)

            assert (
                memory_result[dest_offset : size + dest_offset]
                == expected_memory_result[offset : offset + size]
            )

        @pytest.mark.skip(
            "Investigate why memory results differ in cases where offset and size are gte twenty"
        )
        async def test_extcodecopy_offset_and_size_gte_twenty_a(self, counter, kakarot):
            evm_contract_address = (
                counter.contract_account.deploy_call_info.result.evm_contract_address
            )
            expected_memory_result = hex_string_to_bytes_array(counter.bytecode.hex())

            # instructions
            push1 = 60
            push20 = 73
            extcodecopy = "3c"

            # stack elements
            offset = 10
            size = 10
            dest_offset = 0

            byte_code = f"{push1}\
            {size:02x}\
            {push1}\
            {offset:02x}\
            {push1}\
            {dest_offset:02x}\
            {push20}\
            {evm_contract_address:x}\
            {extcodecopy}"

            res = await kakarot.execute(
                value=int(0),
                bytecode=hex_string_to_bytes_array(byte_code),
                calldata=hex_string_to_bytes_array(""),
            ).call(caller_address=1)

            memory_result = extract_memory_from_execute(res.result)

            assert (
                memory_result[dest_offset : size + dest_offset]
                == expected_memory_result[offset : offset + size]
            )

        @pytest.mark.skip(
            "Investigate why memory results differ in cases where offset and size are gte twenty"
        )
        async def test_extcodecopy_offset_and_size_gte_twenty_b(self, counter, kakarot):
            evm_contract_address = (
                counter.contract_account.deploy_call_info.result.evm_contract_address
            )
            expected_memory_result = hex_string_to_bytes_array(counter.bytecode.hex())

            # instructions
            push1 = 60
            push20 = 73
            extcodecopy = "3c"

            # stack elements
            offset = 11
            size = 9
            dest_offset = 0

            byte_code = f"{push1}\
            {size:02x}\
            {push1}\
            {offset:02x}\
            {push1}\
            {dest_offset:02x}\
            {push20}\
            {evm_contract_address:x}\
            {extcodecopy}"

            res = await kakarot.execute(
                value=int(0),
                bytecode=hex_string_to_bytes_array(byte_code),
                calldata=hex_string_to_bytes_array(""),
            ).call(caller_address=1)

            memory_result = extract_memory_from_execute(res.result)

            assert (
                memory_result[dest_offset : size + dest_offset]
                == expected_memory_result[offset : offset + size]
            )

        @pytest.mark.skip(
            "Investigate why memory results differ in cases where offset and size are gte twenty"
        )
        async def test_extcodecopy_offset_and_size_gte_twenty_c(self, counter, kakarot):
            evm_contract_address = (
                counter.contract_account.deploy_call_info.result.evm_contract_address
            )
            expected_memory_result = hex_string_to_bytes_array(counter.bytecode.hex())

            # instructions
            push1 = 60
            push20 = 73
            extcodecopy = "3c"

            # stack elements
            offset = 18
            size = 3
            dest_offset = 0

            byte_code = f"{push1}\
            {size:02x}\
            {push1}\
            {offset:02x}\
            {push1}\
            {dest_offset:02x}\
            {push20}\
            {evm_contract_address:x}\
            {extcodecopy}"

            res = await kakarot.execute(
                value=int(0),
                bytecode=hex_string_to_bytes_array(byte_code),
                calldata=hex_string_to_bytes_array(""),
            ).call(caller_address=1)

            memory_result = extract_memory_from_execute(res.result)

            assert (
                memory_result[dest_offset : size + dest_offset]
                == expected_memory_result[offset : offset + size]
            )

        @pytest.mark.skip(
            "Investigate why there is a difference between local and deployed contract code in the erc20 contract"
        )
        async def test_extcodecopy_erc20(self, erc_20, kakarot):
            evm_contract_address = (
                erc_20.contract_account.deploy_call_info.result.evm_contract_address
            )

            # instructions
            push1 = 60
            push20 = 73
            extcodecopy = "3c"

            # stack elements
            offset = 0
            size = 8
            dest_offset = 0

            byte_code = f"{push1}\
            {size:02x}\
            {push1}\
            {offset:02x}\
            {push1}\
            {dest_offset:02x}\
            {push20}\
            {evm_contract_address:x}\
            {extcodecopy}"

            res = await kakarot.execute(
                value=int(0),
                bytecode=hex_string_to_bytes_array(byte_code),
                calldata=hex_string_to_bytes_array(""),
            ).call(caller_address=1)

            expected_memory_result = hex_string_to_bytes_array(erc_20.bytecode.hex())
            memory_result = extract_memory_from_execute(res.result)
            # asserting to the first discrepancy
            assert memory_result[dest_offset:2] == expected_memory_result[offset:2]

    class TestLog:
        @pytest.fixture
        def event(self):
            return {
                "owner": Web3.toChecksumAddress(f"{10:040x}"),
                "spender": Web3.toChecksumAddress(f"{11:040x}"),
                "value": 10,
            }

        async def test_should_emit_log0_with_no_data(self, plain_opcodes, addresses):
            await plain_opcodes.opcodeLog0(
                caller_address=addresses[0].starknet_contract.contract_address
            )
            assert plain_opcodes.events.Log0 == [{}]

        async def test_should_emit_log0_with_data(
            self, plain_opcodes, addresses, event
        ):
            await plain_opcodes.opcodeLog0Value(
                caller_address=addresses[0].starknet_contract.contract_address
            )
            assert plain_opcodes.events.Log0Value == [{"value": event["value"]}]

        async def test_should_emit_log1(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog1(
                caller_address=addresses[0].starknet_contract.contract_address
            )
            assert plain_opcodes.events.Log1 == [{"value": event["value"]}]

        async def test_should_emit_log2(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog2(
                caller_address=addresses[0].starknet_contract.contract_address
            )
            del event["spender"]
            assert plain_opcodes.events.Log2 == [event]

        async def test_should_emit_log3(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog3(
                caller_address=addresses[0].starknet_contract.contract_address
            )
            assert plain_opcodes.events.Log3 == [event]

        async def test_should_emit_log4(self, plain_opcodes, addresses, event):
            await plain_opcodes.opcodeLog4(
                caller_address=addresses[0].starknet_contract.contract_address
            )
            assert plain_opcodes.events.Log4 == [event]
