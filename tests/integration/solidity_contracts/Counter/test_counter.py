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
