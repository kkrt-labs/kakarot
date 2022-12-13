from typing import Callable

import pytest
from starkware.starknet.testing.contract import StarknetContract

from tests.integration.helpers.helpers import (
    extract_memory_from_execute,
    hex_string_to_bytes_array,
)


@pytest.mark.asyncio
class TestCounter:
    # TODO move opcodes testing in the PlainOpcode contract
    async def test_extcodecopy_counter(
        self, deploy_solidity_contract: Callable, kakarot: StarknetContract
    ):

        counter = await deploy_solidity_contract("Counter", caller_address=1)

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
    async def test_extcodecopy_offset_and_size_gte_twenty_a(
        self, deploy_solidity_contract: Callable, kakarot: StarknetContract
    ):
        counter = await deploy_solidity_contract("Counter", caller_address=1)

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
    async def test_extcodecopy_offset_and_size_gte_twenty_b(
        self, deploy_solidity_contract: Callable, kakarot: StarknetContract
    ):
        counter = await deploy_solidity_contract("Counter", caller_address=1)

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
    async def test_extcodecopy_offset_and_size_gte_twenty_c(
        self, deploy_solidity_contract: Callable, kakarot: StarknetContract
    ):
        counter = await deploy_solidity_contract("Counter", caller_address=1)

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

        byte_code_for_success = f"{push1}\
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

    @pytest.mark.parametrize(
        "case",
        [
            {
                "bytecode_match": {
                    "offset": 0,
                    "size": 32,
                    "dest_offset": 0,
                },
                "bytecode_zeroed": {
                    "offset": 0,
                    "size": 8,
                    "dest_offset": 1,
                    "contract_address": "mock",
                },
            },
            {
                "bytecode_match": {
                    "offset": 0,
                    "size": 32,
                    "dest_offset": 0,
                },
                "bytecode_zeroed": {
                    "offset": 0,
                    "size": 8,
                    "dest_offset": 1,
                    "contract_address": "counter",
                },
            },
        ],
    )
    async def test_extcodecopy_should_pad_zeroes(
        self,
        deploy_solidity_contract: Callable,
        kakarot: StarknetContract,
        addresses,
        case,
    ):

        counter = await deploy_solidity_contract("Counter", caller_address=1)

        # instructions
        push1 = 60
        push2 = 61
        push20 = 73
        extcodecopy = "3c"
        opcode_template = "{}\
        {size}\
        {}\
        {offset}\
        {}\
        {dest_offset}\
        {}\
        {evm_contract_address}\
        3c"

        bytecode_match_evm_contract_address = (
            counter.contract_account.deploy_call_info.result.evm_contract_address
        )
        local_bytecode = hex_string_to_bytes_array(counter.bytecode.hex())

        # format params for bytecode string

        if case["bytecode_zeroed"]["contract_address"] == "counter":
            zeroed_contract_address_push_opcode = push20
            zeroed_evm_contract_address = f"{bytecode_match_evm_contract_address:x}"
            zeroed_contract_offset_push_opcode = push2
            # when a case requests a deployed contract,
            # we set its offset to the length of the deployed contract
            zeroed_contract_offset = f"{len(local_bytecode):04x}"
        else:
            zeroed_contract_address_push_opcode = push1
            zeroed_evm_contract_address = f"{addresses[0]['int']:02x}"
            zeroed_contract_offset_push_opcode = push1
            zeroed_contract_offset = f"{case['bytecode_zeroed']['offset']:02x}"

        match_size = f"{case['bytecode_match']['size']:02x}"
        match_offset = f"{case['bytecode_match']['offset']:02x}"
        match_dest_offset = f"{case['bytecode_match']['dest_offset']:02x}"
        match_address = f"{bytecode_match_evm_contract_address:x}"

        zeroed_dest_offset = f"{case['bytecode_zeroed']['dest_offset']:02x}"
        zeroed_size = f"{case['bytecode_zeroed']['size']:02x}"
        # we set up instructions to have bytecode in the memory
        # in this case the bytecode of the deployed counter contract
        bytecode_match = opcode_template.format(
            push1,
            push1,
            push1,
            push20,
            size=match_size,
            offset=match_offset,
            dest_offset=match_dest_offset,
            evm_contract_address=match_address,
        )

        # then we set up instructions to attempt to copy code
        # in a case where we should see zeroed in memory
        bytecode_zeroed = opcode_template.format(
            push1,
            zeroed_contract_offset_push_opcode,
            push1,
            zeroed_contract_address_push_opcode,
            size=zeroed_size,
            offset=zeroed_contract_offset,
            dest_offset=zeroed_dest_offset,
            evm_contract_address=zeroed_evm_contract_address,
        )

        match_res = await kakarot.execute(
            value=int(0),
            bytecode=hex_string_to_bytes_array(bytecode_match),
            calldata=hex_string_to_bytes_array(""),
        ).call(caller_address=1)

        res = await kakarot.execute(
            value=int(0),
            bytecode=hex_string_to_bytes_array(bytecode_match + bytecode_zeroed),
            calldata=hex_string_to_bytes_array(""),
        ).call(caller_address=1)

        # note:
        # we compare the bytecode to how it is stored in the registry
        # due to issues as mentioned in issue number 342
        memory_result = extract_memory_from_execute(match_res.result)
        zeroed_memory_result = extract_memory_from_execute(res.result)

        # we expect the contract byte code to match up till `dest_offset`
        # as defined in the zeroed case
        zeroed_dest_offset = case["bytecode_zeroed"]["dest_offset"]

        assert (
            zeroed_memory_result[0:zeroed_dest_offset]
            == memory_result[0:zeroed_dest_offset]
        )

        # we assert that from the `zeroed_dest_offset`
        # to the zeroed case size, we get zeroes

        zeroed_region_size = case["bytecode_zeroed"]["size"]
        zeroed_region_boundary = zeroed_dest_offset + zeroed_region_size

        assert (
            zeroed_memory_result[zeroed_dest_offset:zeroed_region_boundary]
            == [0] * zeroed_region_size
        )

        end_of_zeroed_region = zeroed_region_boundary + 1
        memory_result_size = case["bytecode_match"]["size"]

        # finally, we assert that from the `end_of_zeroed_region`
        # to `memory_result_size` the results are the same.

        # note (as previously mentioned)
        # we compare the bytecode to how it is stored in the registry
        # due to issues as mentioned in issue number 342
        assert (
            zeroed_memory_result[end_of_zeroed_region:memory_result_size]
            == memory_result[end_of_zeroed_region:memory_result_size]
        )
