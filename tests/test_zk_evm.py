from textwrap import wrap
from time import time

import pytest
import pytest_asyncio


@pytest_asyncio.fixture(scope="session")
async def zk_evm(starknet, eth):
    start = time()
    contract_hash = await starknet.declare(
        source="./src/kakarot/accounts/contract/contract_account.cairo",
        cairo_path=["src"],
        disable_hint_validation=0,
    )
    _zk_evm = await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[1, eth.contract_address, contract_hash.class_hash],
    )
    evm_time = time()
    print(f"\nzkEVM deployed in {evm_time - start:.2f}s")
    registry = await starknet.deploy(
        source="./src/kakarot/accounts/registry/account_registry.cairo",
        cairo_path=["src"],
        disable_hint_validation=True,
        constructor_calldata=[_zk_evm.contract_address],
    )
    registry_time = time()
    print(f"AccountRegistry deployed in {registry_time - evm_time:.2f}s")
    await _zk_evm.set_account_registry(
        registry_address_=registry.contract_address
    ).execute(caller_address=1)
    account_time = time()
    print(f"zkEVM set in {account_time - registry_time:.2f}s")
    res = await _zk_evm.deploy(bytes=[1, 12312]).call(caller_address=1)
    print("Contract Address: ", res)
    return _zk_evm


test_cases = [
    {
        "params": {
            "code": "600160015500",
            "calldata": "",
            "stack": "",
            "memory": "",
            "return_value": "",
        },
        "id": "sstore",
    },
    {
        "params": {
            "code": "60056003600039",
            "calldata": "",
            "stack": "",
            "memory": "0360003900000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "codecopy",
    },
    {
        "params": {
            "code": "7dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6008601f600039",
            "calldata": "",
            "stack": "1766847064778384329583297500742918515827483896875618958121606201292619775",
            "memory": "6008601f60003900000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "codecopy2",
    },
    {
        "params": {
            "code": "6003600401600a02608c036102bc04604605600d066010076005600608601060020960040A60600B00",
            "calldata": "",
            "stack": "16",
            "memory": "",
            "return_value": "",
        },
        "id": "Arithmetic operations",
    },
    {
        "params": {
            "code": "60018060036004600260058300",
            "calldata": "",
            "stack": "1,1,3,4,2,5,3",
            "memory": "",
            "return_value": "",
        },
        "id": "Duplication operations",
    },
    {
        "params": {
            "code": "600160001d",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "600060011d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f400000000000000000000000000000000000000000000000000000000000000060fe1d",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60f81d",
            "calldata": "",
            "stack": "127",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60fe1d",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "600160011d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060011d",
            "calldata": "",
            "stack": "86844066927987146567678238756515930889952488499230423029593188005934847229952",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060ff1d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101001d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101011d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60001d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SAR",
    },
    {
        "params": {
            "code": "600160001b",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "600060011b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011b",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639934",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "600160011b",
            "calldata": "",
            "stack": "2",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "600160ff1b",
            "calldata": "",
            "stack": "57896044618658097711785492504343953926634992332820282019728792003956564819968",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "60016101001b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "60016101011b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60001b",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011b",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639934",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1b",
            "calldata": "",
            "stack": "57896044618658097711785492504343953926634992332820282019728792003956564819968",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHL",
    },
    {
        "params": {
            "code": "600160001c",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "600060011c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "600160011c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060011c",
            "calldata": "",
            "stack": "28948022309329048855892746252171976963317496166410141009864396001978282409984",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060ff1c",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101001c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101011c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60001c",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011c",
            "calldata": "",
            "stack": "57896044618658097711785492504343953926634992332820282019728792003956564819967",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1c",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SHR",
    },
    {
        "params": {
            "code": "6005600516",
            "calldata": "",
            "stack": "5",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - AND",
    },
    {
        "params": {
            "code": "600a600a146009600a14",
            "calldata": "",
            "stack": "1,0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - EQ",
    },
    {
        "params": {
            "code": "600a600a116009600a11",
            "calldata": "",
            "stack": "0,1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - GT",
    },
    {
        "params": {
            "code": "600015",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - ISZERO",
    },
    {
        "params": {
            "code": "600a600910600a600a10",
            "calldata": "",
            "stack": "1,0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - LT",
    },
    {
        "params": {
            "code": "600019",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - NOT",
    },
    {
        "params": {
            "code": "6005600317",
            "calldata": "",
            "stack": "7",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - OR",
    },
    {
        "params": {
            "code": "60ff600113",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SGT",
    },
    {
        "params": {
            "code": "60ff600112",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Comparison & bitwise logic operations - SLT",
    },
    {
        "params": {
            "code": "600360026001916004929200",
            "calldata": "",
            "stack": "1,2,3,4",
            "memory": "",
            "return_value": "",
        },
        "id": "Exchange operations",
    },
    {
        "params": {
            "code": "60016101023800",
            "calldata": "",
            "stack": "1,258,7",
            "memory": "",
            "return_value": "",
        },
        "id": "Environmental information",
    },
    {
        "params": {
            "code": "600160024600",
            "calldata": "",
            "stack": "1,2,1263227476",
            "memory": "",
            "return_value": "",
        },
        "id": "Block information CHAINID",
    },
    {
        "params": {
            "code": "4100",
            "calldata": "",
            "stack": "1598625851760128517552627854997699631064626954749952456622017584404508471300",
            "memory": "",
            "return_value": "",
        },
        "id": "Block information COINBASE",
    },
    {
        "params": {
            "code": "60016002FE",
            "calldata": "",
            "stack": "1,2",
            "memory": "",
            "return_value": "",
        },
        "id": "System operations INVALID",
        "marks": pytest.mark.xfail,
    },
    {
        "params": {
            "code": "4300",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Block information NUMBER",
    },
    {
        "params": {
            "code": "4200",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Block information TIMESTAMP",
    },
    {
        "params": {
            "code": "3200",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Origin Address",
    },
    {
        "params": {
            "code": "3300",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Caller Address",
    },
    {
        "params": {
            "code": "610100600052602060002000",
            "calldata": "",
            "stack": "31605475728638136284098257830937953109142906242585568807375082376557418698875",
            "memory": "0000000000000000000000000000000000000000000000000000000000000100",
            "return_value": "",
        },
        "id": "Hash 32 bytes",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "60106000526001601f2000",
            "calldata": "",
            "stack": "68071607937700842810429351077030899797510977729217708600998965445571406158526",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
        },
        "id": "Hash 1 byte with offset 1f",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "6010600052600160002000",
            "calldata": "",
            "stack": "85131057757245807317576516368191972321038229705283732634690444270750521936266",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
        },
        "id": "Hash 1 byte no offset",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "6010600052600760002000",
            "calldata": "",
            "stack": "101225983456080153511598605893998939348063346639131267901574990367534118792751",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
        },
        "id": "Hash 7 bytes",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "6010600052600860002000",
            "calldata": "",
            "stack": "500549258012437878224561338362079327067368301550791134293299473726337612750",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
        },
        "id": "Hash 8 bytes",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "6010600052600960002000",
            "calldata": "",
            "stack": "78337347954576241567341556127836028920764967266964912349540464394612926403441",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
        },
        "id": "Hash 9 bytes",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "6010600052601160002000",
            "calldata": "",
            "stack": "41382199742381387985558122494590197322490258008471162768551975289239028668781",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
        },
        "id": "Hash 17 bytes",
        "marks": pytest.mark.sha3,
    },
    {
        "params": {
            "code": "4500",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Gas Limit",
    },
    {
        "params": {
            "code": "3d00",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Get the size of return data - 0x3d RETURNDATASIZE",
    },
    {
        "params": {
            "code": "600a4400",
            "calldata": "",
            "stack": "10,0",
            "memory": "",
            "return_value": "",
        },
        "id": "Load Word from Memory",
    },
    {
        "params": {
            "code": "600a4800",
            "calldata": "",
            "stack": "10,10",
            "memory": "",
            "return_value": "",
        },
        "id": "Load Word from Memory",
        "marks": pytest.mark.skip("Returned stack is 10,0 instead of 10,10"),
    },
    {
        "params": {
            "code": "600035",
            "calldata": "000000000000000000000000000000000000000000000000000000000000000a",
            "stack": "10",
            "memory": "",
            "return_value": "",
        },
        "id": "Load CallData onto the Stack - 0x35 CALLDATALOAD",
    },
    {
        "params": {
            "code": "3600",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Get the size of calldata - 0x36 CALLDATASIZE",
    },
    {
        "params": {
            "code": "60013100",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Balance",
    },
    {
        "params": {
            "code": "600a60005200",
            "calldata": "",
            "stack": "",
            "memory": "000000000000000000000000000000000000000000000000000000000000000a",
            "return_value": "",
        },
        "id": "Memory operations",
    },
    {
        "params": {
            "code": "600a60005260fa60245200",
            "calldata": "",
            "stack": "",
            "memory": "000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000fa00000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Memory operations",
        "marks": pytest.mark.skip("Returned memory missed the last empty bytes32"),
    },
    {
        "params": {
            "code": "58600158",
            "calldata": "",
            "stack": "0,1,3",
            "memory": "",
            "return_value": "",
        },
        "id": "Memory operation - PC",
    },
    {
        "params": {
            "code": "5900",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Get Memory Size",
    },
    {
        "params": {
            "code": "600a600052600051",
            "calldata": "",
            "stack": "10",
            "memory": "000000000000000000000000000000000000000000000000000000000000000a",
            "return_value": "",
        },
        "id": "Load Word from Memory",
    },
    {
        "params": {
            "code": "5860015b6001600158",
            "calldata": "",
            "stack": "0,1,1,1,8",
            "memory": "",
            "return_value": "",
        },
        "id": "Jumpdest opcode",
    },
    {
        "params": {
            "code": "600556600a5b600b",
            "calldata": "",
            "stack": "11",
            "memory": "",
            "return_value": "",
        },
        "id": "JUMP opcode",
        "marks": pytest.mark.skip("Returned stack is 10,11 instead of 11"),
    },
    {
        "params": {
            "code": "6001600757600a5b600a6000600857600a01",
            "calldata": "",
            "stack": "20",
            "memory": "",
            "return_value": "",
        },
        "id": "JUMP if condition is met",
        "marks": pytest.mark.skip("Returned stack is 10,20 instead of 20"),
    },
    {
        "params": {
            "code": "601160405200",
            "calldata": "",
            "stack": "",
            "memory": "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011",
            "return_value": "",
        },
        "id": "Memory operations - Check very large offsets",
    },
    {
        "params": {
            "code": "6011604052602260405200",
            "calldata": "",
            "stack": "",
            "memory": "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022",
            "return_value": "",
        },
        "id": "Memory operations - Check Colliding offsets",
    },
    {
        "params": {
            "code": "7d111111111111111111111111111111111111111111111111111111111111600052",
            "calldata": "",
            "stack": "",
            "memory": "0000111111111111111111111111111111111111111111111111111111111111",
            "return_value": "",
        },
        "id": "Memory operations - Check saving memory with 30 bytes",
    },
    {
        "params": {
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff604052601160355200",
            "calldata": "",
            "stack": "",
            "memory": "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011ffffffffffffffffffffff",
            "return_value": "",
        },
        "id": "Memory operations - Check saving memory in between an already saved memory location",
    },
    {
        "params": {
            "code": "611122600353",
            "calldata": "",
            "stack": "",
            "memory": "0000002200000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Memory operations - Check saving memory in between an already saved memory location",
    },
    {
        "params": {
            "code": "7f111111111111111111111111111111111111111111111111111111111111111160005261222260055300",
            "calldata": "",
            "stack": "",
            "memory": "1111111111221111111111111111111111111111111111111111111111111111",
            "return_value": "",
        },
        "id": "Memory operations - Check saving memory in between an already saved memory location",
    },
    {
        "params": {
            "code": "6020600560063700",
            "calldata": "00112233445566778899aabbcceeddff",
            "stack": "",
            "memory": "0000000000005566778899aabbcceeddff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "calldatacopy",
    },
    {
        "params": {
            "code": "7f00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff60005260106003600337",
            "calldata": "11111111111111111111111111111111111111111111111111111111111111111111",
            "stack": "",
            "memory": "0011221111111111111111111111111111111133445566778899aabbccddeeff",
            "return_value": "",
        },
        "id": "calldatacopy1",
    },
    {
        "params": {
            "code": "60246005600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": "5566778899aabbcceeddff00112233445566778899aabbccddeeff00000000000000000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "calldatacopy2",
    },
    {
        "params": {
            "code": "60206005600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": "5566778899aabbcceeddff00112233445566778899aabbccddeeff0011223344",
            "return_value": "",
        },
        "id": "calldatacopy3",
    },
    {
        "params": {
            "code": "60406003600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": "33445566778899aabbcceeddff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "calldatacopy4",
    },
    {
        "params": {
            "code": "60106005600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": "5566778899aabbcceeddff001122334400000000000000000000000000000000",
            "return_value": "",
        },
        "id": "calldatacopy5",
    },
    {
        "params": {
            "code": "60106000526001601fA000",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
            "events": [[[], [0x10]]],
        },
        "id": "PRElog0",
    },
    {
        "params": {
            "code": "601060005260016022A000",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010000000",
            "return_value": "",
            "events": [[[], [0x00]]],
        },
        "id": "PRElog0-1",
    },
    {
        "params": {
            "code": "60106000527FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6001601fA100",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
            "events": [
                [
                    [
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                    ],
                    [0x10],
                ]
            ],
        },
        "id": "PRElog1",
    },
    {
        "params": {
            "code": "601060005260FF60016022A100",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010000000",
            "return_value": "",
            "events": [[[0xFF, 0x00], [0x00]]],
        },
        "id": "PRElog1-1",
    },
    {
        "params": {
            "code": "60106000527FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF60FF6001601fA200",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
            "events": [
                [
                    [
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFF,
                        0x00,
                    ],
                    [0x10],
                ]
            ],
        },
        "id": "PRElog2",
    },
    {
        "params": {
            "code": "6010600052600060FF60016022A200",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010000000",
            "return_value": "",
            "events": [[[0x00, 0x00, 0xFF, 0x00], [0x00]]],
        },
        "id": "PRElog2-1",
    },
    {
        "params": {
            "code": "601060005260AB7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF60FF6001601fA300",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
            "events": [
                [
                    [
                        0xAB,
                        0x00,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFF,
                        0x00,
                    ],
                    [0x10],
                ]
            ],
        },
        "id": "PRElog3",
    },
    {
        "params": {
            "code": "601060005260AB600060FF60016022A300",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010000000",
            "return_value": "",
            "events": [[[0xAB, 0x00, 0x00, 0x00, 0xFF, 0x00], [0x00]]],
        },
        "id": "PRElog3-1",
    },
    {
        "params": {
            "code": "6010600052600860AB7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF60FF6001601fA400",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_value": "",
            "events": [
                [
                    [
                        0x08,
                        0x00,
                        0xAB,
                        0x00,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFF,
                        0x00,
                    ],
                    [0x10],
                ]
            ],
        },
        "id": "PRElog4",
    },
    {
        "params": {
            "code": "6010600052600860AB600060FF60016022A400",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010000000",
            "return_value": "",
            "events": [[[0x08, 0x00, 0xAB, 0x00, 0x00, 0x00, 0xFF, 0x00], [0x00]]],
        },
        "id": "PRElog4-1",
    },
]


params = [pytest.param(case.pop("params"), **case) for case in test_cases]


@pytest.mark.asyncio
class TestZkEVM:
    @staticmethod
    def int_to_uint256(value):
        low = value & ((1 << 128) - 1)
        high = value >> 128
        return low, high

    @pytest.mark.parametrize(
        "params",
        params,
    )
    async def test_case(self, zk_evm, params):
        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        res = await zk_evm.execute(
            code=[int(b, 16) for b in wrap(params["code"], 2)],
            calldata=[int(b, 16) for b in wrap(params["calldata"], 2)],
        ).call(caller_address=1)
        assert res.result.stack == [
            Uint256(*self.int_to_uint256(int(s)))
            for s in (params["stack"].split(",") if params["stack"] else [])
        ]
        assert res.result.memory == [int(m, 16) for m in wrap(params["memory"], 2)]
        events = params.get("events")
        if events:
            assert [
                [
                    event.keys,
                    event.data,
                ]
                for event in sorted(res.call_info.events, key=lambda x: x.order)
            ] == events
