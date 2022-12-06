import pytest
from starkware.starknet.testing.contract import StarknetContract

from typing import Callable

from tests.integration.test_cases import params_execute
from tests.utils.reporting import traceit
from tests.utils.utils import (
    extract_memory_from_execute,
    extract_stack_from_execute,
    hex_string_to_bytes_array,
)

@pytest.mark.asyncio
class TestKakarot:
    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, kakarot: StarknetContract, params: dict, request):
        with traceit.context(request.node.callspec.id):
            res = await kakarot.execute(
                value=int(params["value"]),
                bytecode=hex_string_to_bytes_array(params["code"]),
                calldata=hex_string_to_bytes_array(params["calldata"]),
            ).call(caller_address=1)

        stack_result = extract_stack_from_execute(res.result)
        memory_result = extract_memory_from_execute(res.result)

        assert stack_result == (
            [int(x) for x in params["stack"].split(",")] if params["stack"] else []
        )
        assert memory_result == hex_string_to_bytes_array(params["memory"])

        events = params.get("events")
        if events:
            assert [
                [
                    event.keys,
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events

    @pytest.mark.skip("Investigate why there is a difference between local and deployed contract code in the erc20 contract")            
    async def test_extcodecopy_erc20(self, deploy_solidity_contract: Callable, kakarot: StarknetContract):

        erc_20 = await deploy_solidity_contract(
            "ERC20", "Kakarot Token", "KKT", 18, caller_address=1
        )        
        
        evm_contract_address = erc_20.contract_account.deploy_call_info.result.evm_contract_address

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

            
    async def test_extcodecopy_counter(self, deploy_solidity_contract: Callable, kakarot: StarknetContract):

        counter = await deploy_solidity_contract(
            "Counter", caller_address=1
        )
        
        evm_contract_address = counter.contract_account.deploy_call_info.result.evm_contract_address

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

        assert memory_result[dest_offset:size+dest_offset] == expected_memory_result[offset:offset+size]

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

        assert memory_result[dest_offset:size+dest_offset] == expected_memory_result[offset:offset+size]

    @pytest.mark.skip("Investigate why memory results differ in cases where offset and size are gte twenty")
    async def test_extcodecopy_offset_and_size_gte_twenty_a(self, deploy_solidity_contract: Callable, kakarot: StarknetContract):
        counter = await deploy_solidity_contract(
            "Counter", caller_address=1
        )
        
        evm_contract_address = counter.contract_account.deploy_call_info.result.evm_contract_address
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

        assert memory_result[dest_offset:size+dest_offset] == expected_memory_result[offset:offset+size]

    @pytest.mark.skip("Investigate why memory results differ in cases where offset and size are gte twenty")
    async def test_extcodecopy_offset_and_size_gte_twenty_b(self, deploy_solidity_contract: Callable, kakarot: StarknetContract):
        counter = await deploy_solidity_contract(
            "Counter", caller_address=1
        )
        
        evm_contract_address = counter.contract_account.deploy_call_info.result.evm_contract_address
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

        assert memory_result[dest_offset:size+dest_offset] == expected_memory_result[offset:offset+size]        

    @pytest.mark.skip("Investigate why memory results differ in cases where offset and size are gte twenty")
    async def test_extcodecopy_offset_and_size_gte_twenty_c(self, deploy_solidity_contract: Callable, kakarot: StarknetContract):
        counter = await deploy_solidity_contract(
            "Counter", caller_address=1
        )
        
        evm_contract_address = counter.contract_account.deploy_call_info.result.evm_contract_address
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

        assert memory_result[dest_offset:size+dest_offset] == expected_memory_result[offset:offset+size]

    
