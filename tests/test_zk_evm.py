from textwrap import wrap
from time import time

import pytest
import pytest_asyncio
from starkware.starknet.testing.contract import DeclaredClass, StarknetContract
from starkware.starknet.testing.starknet import Starknet


@pytest_asyncio.fixture(scope="module")
async def zk_evm(
    starknet: Starknet, eth: StarknetContract, contract_account_class: DeclaredClass
):
    start = time()
    _zk_evm = await starknet.deploy(
        source="./src/kakarot/kakarot.cairo",
        cairo_path=["src"],
        disable_hint_validation=False,
        constructor_calldata=[
            1,
            eth.contract_address,
            contract_account_class.class_hash,
        ],
    )
    evm_time = time()
    print(f"\nzkEVM deployed in {evm_time - start:.2f}s")
    return _zk_evm


@pytest_asyncio.fixture(scope="module", autouse=True)
async def set_account_registry(zk_evm, account_registry):
    await account_registry.transfer_ownership(zk_evm.contract_address).execute(
        caller_address=1
    )
    await zk_evm.set_account_registry(
        registry_address_=account_registry.contract_address
    ).execute(caller_address=1)
    yield
    await account_registry.transfer_ownership(1).execute(
        caller_address=zk_evm.contract_address
    )


# Test cases for TestZkEVM.test_execute
test_cases_execute = [
    {
        "params": {
            "code": "604260005260206000F3",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000042",
            "return_value": "0000000000000000000000000000000000000000000000000000000000000042",
        },
        "id": "return",
        "marks": [pytest.mark.RETURN, pytest.mark.SystemOperations],
    },
    {
        "params": {
            "code": "60016001f3",
            "calldata": "",
            "stack": "",
            "memory": "",
            "return_value": "00",
        },
        "id": "return2",
        "marks": [pytest.mark.RETURN, pytest.mark.SystemOperations],
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
        "marks": [pytest.mark.CODECOPY, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.CODECOPY, pytest.mark.EnvironmentalInformation],
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
        "marks": [
            pytest.mark.ADD,
            pytest.mark.MUL,
            pytest.mark.SUB,
            pytest.mark.DIV,
            pytest.mark.SDIV,
            pytest.mark.MOD,
            pytest.mark.SMOD,
            pytest.mark.ADDMOD,
            pytest.mark.MULMOD,
            pytest.mark.EXP,
            pytest.mark.SIGNEXTEND,
            pytest.mark.ArithmeticOperations,
        ],
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
        "marks": [pytest.mark.DUP, pytest.mark.DuplicationOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.AND, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.EQ, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.GT, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.ISZERO, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.LT, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.NOT, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.OR, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SGT, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SLT, pytest.mark.ComparisonBitwiseLogicOperations],
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
        "marks": [pytest.mark.SWAP, pytest.mark.ExchangeOperations],
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
        "marks": [pytest.mark.CODESIZE, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.CHAINID, pytest.mark.BlockInformation],
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
        "marks": [pytest.mark.COINBASE, pytest.mark.BlockInformation],
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
        "marks": [pytest.mark.INVALID, pytest.mark.SystemOperations, pytest.mark.xfail],
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
        "marks": [pytest.mark.NUMBER, pytest.mark.BlockInformation],
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
        "marks": [pytest.mark.TIMESTAMP, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "code": "4700",
            "calldata": "",
            "stack": "0000000000000000000000000000000000000000000000000000000000000000",
            "memory": "",
            "return_value": "",
        },
        "id": "Get balance of currently executing contract - 0x47 SELFBALANCE",
        "marks": [pytest.mark.SELFBALANCE, pytest.mark.BlockInformation],
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
        "marks": [pytest.mark.ORIGIN, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.CALLER, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.SHA3],
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
        "marks": [pytest.mark.SHA3],
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
        "marks": [pytest.mark.SHA3],
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
        "marks": [pytest.mark.SHA3],
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
        "marks": [pytest.mark.SHA3],
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
        "marks": [pytest.mark.SHA3],
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
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "code": "4500",
            "calldata": "",
            "stack": "1000000",
            "memory": "",
            "return_value": "",
        },
        "id": "Gas Limit",
        "marks": [pytest.mark.GASLIMIT, pytest.mark.BlockInformation],
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
        "marks": [pytest.mark.RETURNDATASIZE, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.DIFFICULTY, pytest.mark.BlockInformation],
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
        "marks": [
            pytest.mark.BASEFEE,
            pytest.mark.BlockInformation,
            pytest.mark.skip("Returned stack is 10,0 instead of 10,10"),
        ],
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
        "marks": [pytest.mark.CALLDATALOAD, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "code": "3600",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_value": "",
        },
        "id": "Get the size of calldata when empty calldata - 0x36 CALLDATASIZE",
        "marks": [pytest.mark.CALLDATASIZE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "code": "3600",
            "calldata": "ff",
            "stack": "1",
            "memory": "",
            "return_value": "",
        },
        "id": "Get the size of calldata when non empty calldata - 0x36 CALLDATASIZE",
        "marks": [pytest.mark.CALLDATASIZE, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.BALANCE, pytest.mark.EnvironmentalInformation],
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
        "marks": [pytest.mark.MSTORE, pytest.mark.StackMemoryStorageFlowOperations],
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
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
            pytest.mark.skip("Returned memory missed the last empty bytes32"),
        ],
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
        "marks": [pytest.mark.PC, pytest.mark.StackMemoryStorageFlowOperations],
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
        "marks": [pytest.mark.MSIZE, pytest.mark.StackMemoryStorageFlowOperations],
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
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.MLOAD,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.JUMPDEST,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.JUMP,
            pytest.mark.StackMemoryStorageFlowOperations,
            pytest.mark.skip("Returned stack is 10,11 instead of 11"),
        ],
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
        "marks": [
            pytest.mark.JUMPI,
            pytest.mark.StackMemoryStorageFlowOperations,
            pytest.mark.skip("Returned stack is 10,20 instead of 20"),
        ],
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
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.MSTORE8,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.MSTORE8,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
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
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
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
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
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
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
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
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
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
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
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
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
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
    {
        "params": {
            "code": "60026000600039",
            "calldata": "",
            "stack": "",
            "memory": "6002000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Environment Information - CODECOPY (0x39) - code slice within bounds, memory offset > len with tail padding",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "code": "7d00112233445566778899aabbccddeeff00112233445566778899aabbccdd60005260086003600139",
            "calldata": "",
            "stack": "",
            "memory": "002233445566778899778899aabbccddeeff00112233445566778899aabbccdd",
            "return_value": "",
        },
        "id": "Environmental Information - CODECOPY (0x39) - code slice within bounds, memory copy within bounds",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "code": "7d00112233445566778899aabbccddeeff00112233445566778899aabbccdd60005260206003600139",
            "calldata": "",
            "stack": "",
            "memory": "002233445566778899aabbccddeeff00112233445566778899aabbccdd6000526000000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Environmental Information - CODECOPY (0x39) - code slice within bounds, memory offset < len < offset + size",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "code": "60386002600339",
            "calldata": "",
            "stack": "",
            "memory": "00000060026003390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Environmental Information - CODECOPY (0x39) - code with padding + memory offset > len ",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "code": "7d00112233445566778899aabbccddeeff00112233445566778899aabbccdd60005260056065600439",
            "calldata": "",
            "stack": "",
            "memory": "000000110000000000778899aabbccddeeff00112233445566778899aabbccdd",
            "return_value": "",
        },
        "id": "Environmental Information - CODECOPY (0x39) - code offset > len, memory offset + size < len",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "code": "7dFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F0000000000000000000000000000000000000000000000000000000000000000505060326000600039",
            "calldata": "",
            "stack": "",
            "memory": "7dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Environment Information - CODECOPY (0x39) - evmcode example 1",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "code": "7dFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F00000000000000000000000000000000000000000000000000000000000000005050603260006000396008601f600039",
            "calldata": "",
            "stack": "",
            "memory": "7f00000000000000ffffffffffffffffffffffffffffffffffffffffffffff7f0000000000000000000000000000000000000000000000000000000000000000",
            "return_value": "",
        },
        "id": "Environment Information - CODECOPY (0x39) - evmcode example 1+2",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
]

# Test cases for TestZkEVM.test_execute_at_address
test_cases_execute_at_address = [
    {
        "params": {
            "code": "608060405234801561001057600080fd5b5060405161080d38038061080d83398101604081905261002f91610197565b815161004290600090602085019061005e565b50805161005690600190602084019061005e565b505050610248565b82805461006a906101f7565b90600052602060002090601f01602090048101928261008c57600085556100d2565b82601f106100a557805160ff19168380011785556100d2565b828001600101855582156100d2579182015b828111156100d25782518255916020019190600101906100b7565b506100de9291506100e2565b5090565b5b808211156100de57600081556001016100e3565b600082601f830112610107578081fd5b81516001600160401b038082111561012157610121610232565b6040516020601f8401601f191682018101838111838210171561014657610146610232565b604052838252858401810187101561015c578485fd5b8492505b8383101561017d5785830181015182840182015291820191610160565b8383111561018d57848185840101525b5095945050505050565b600080604083850312156101a9578182fd5b82516001600160401b03808211156101bf578384fd5b6101cb868387016100f7565b935060208501519150808211156101e0578283fd5b506101ed858286016100f7565b9150509250929050565b60028104600182168061020b57607f821691505b6020821081141561022c57634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052604160045260246000fd5b6105b6806102576000396000f3fe608060405234801561001057600080fd5b50600436106100935760003560e01c806340c10f191161006657806340c10f19146100fe57806370a082311461011357806395d89b4114610126578063a9059cbb1461012e578063dd62ed3e1461014157610093565b806306fdde0314610098578063095ea7b3146100b657806318160ddd146100d657806323b872dd146100eb575b600080fd5b6100a0610154565b6040516100ad91906104a4565b60405180910390f35b6100c96100c4366004610470565b6101e2565b6040516100ad9190610499565b6100de61024c565b6040516100ad91906104f7565b6100c96100f9366004610435565b610252565b61011161010c366004610470565b610304565b005b6100de6101213660046103e2565b61033d565b6100a061034f565b6100c961013c366004610470565b61035c565b6100de61014f366004610403565b6103a9565b600080546101619061052f565b80601f016020809104026020016040519081016040528092919081815260200182805461018d9061052f565b80156101da5780601f106101af576101008083540402835291602001916101da565b820191906000526020600020905b8154815290600101906020018083116101bd57829003601f168201915b505050505081565b3360008181526004602090815260408083206001600160a01b038716808552925280832085905551919290917f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259061023b9086906104f7565b60405180910390a350600192915050565b60025481565b6001600160a01b038316600090815260046020908152604080832033845290915281205460001981146102ae576102898382610518565b6001600160a01b03861660009081526004602090815260408083203384529091529020555b6001600160a01b038516600090815260036020526040812080548592906102d6908490610518565b9091555050506001600160a01b03831660009081526003602052604090208054830190555060019392505050565b80600260008282546103169190610500565b90915550506001600160a01b03909116600090815260036020526040902080549091019055565b60036020526000908152604090205481565b600180546101619061052f565b3360009081526003602052604081208054839190839061037d908490610518565b9091555050506001600160a01b0382166000908152600360205260409020805482019055600192915050565b600460209081526000928352604080842090915290825290205481565b80356001600160a01b03811681146103dd57600080fd5b919050565b6000602082840312156103f3578081fd5b6103fc826103c6565b9392505050565b60008060408385031215610415578081fd5b61041e836103c6565b915061042c602084016103c6565b90509250929050565b600080600060608486031215610449578081fd5b610452846103c6565b9250610460602085016103c6565b9150604084013590509250925092565b60008060408385031215610482578182fd5b61048b836103c6565b946020939093013593505050565b901515815260200190565b6000602080835283518082850152825b818110156104d0578581018301518582016040015282016104b4565b818111156104e15783604083870101525b50601f01601f1916929092016040019392505050565b90815260200190565b600082198211156105135761051361056a565b500190565b60008282101561052a5761052a61056a565b500390565b60028104600182168061054357607f821691505b6020821081141561056457634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052601160045260246000fdfea26469706673582212204e53876a7abf080ce7b38dffe1572ec4843a83c565efd2feeb856984b5af6fb764736f6c634300080000330000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000074b616b61726f74000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003534a4e0000000000000000000000000000000000000000000000000000000000",
            "calldata": "40c10f1900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000164",
            "stack": "",
            "memory": "",
            "return_value": "",
        },
        "id": "solmate_erc20_mint",
        "marks": [pytest.mark.SolmateERC20],
    },
    {
        "params": {
            "code": "608060405234801561001057600080fd5b5060405161080d38038061080d83398101604081905261002f91610197565b815161004290600090602085019061005e565b50805161005690600190602084019061005e565b505050610248565b82805461006a906101f7565b90600052602060002090601f01602090048101928261008c57600085556100d2565b82601f106100a557805160ff19168380011785556100d2565b828001600101855582156100d2579182015b828111156100d25782518255916020019190600101906100b7565b506100de9291506100e2565b5090565b5b808211156100de57600081556001016100e3565b600082601f830112610107578081fd5b81516001600160401b038082111561012157610121610232565b6040516020601f8401601f191682018101838111838210171561014657610146610232565b604052838252858401810187101561015c578485fd5b8492505b8383101561017d5785830181015182840182015291820191610160565b8383111561018d57848185840101525b5095945050505050565b600080604083850312156101a9578182fd5b82516001600160401b03808211156101bf578384fd5b6101cb868387016100f7565b935060208501519150808211156101e0578283fd5b506101ed858286016100f7565b9150509250929050565b60028104600182168061020b57607f821691505b6020821081141561022c57634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052604160045260246000fd5b6105b6806102576000396000f3fe608060405234801561001057600080fd5b50600436106100935760003560e01c806340c10f191161006657806340c10f19146100fe57806370a082311461011357806395d89b4114610126578063a9059cbb1461012e578063dd62ed3e1461014157610093565b806306fdde0314610098578063095ea7b3146100b657806318160ddd146100d657806323b872dd146100eb575b600080fd5b6100a0610154565b6040516100ad91906104a4565b60405180910390f35b6100c96100c4366004610470565b6101e2565b6040516100ad9190610499565b6100de61024c565b6040516100ad91906104f7565b6100c96100f9366004610435565b610252565b61011161010c366004610470565b610304565b005b6100de6101213660046103e2565b61033d565b6100a061034f565b6100c961013c366004610470565b61035c565b6100de61014f366004610403565b6103a9565b600080546101619061052f565b80601f016020809104026020016040519081016040528092919081815260200182805461018d9061052f565b80156101da5780601f106101af576101008083540402835291602001916101da565b820191906000526020600020905b8154815290600101906020018083116101bd57829003601f168201915b505050505081565b3360008181526004602090815260408083206001600160a01b038716808552925280832085905551919290917f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259061023b9086906104f7565b60405180910390a350600192915050565b60025481565b6001600160a01b038316600090815260046020908152604080832033845290915281205460001981146102ae576102898382610518565b6001600160a01b03861660009081526004602090815260408083203384529091529020555b6001600160a01b038516600090815260036020526040812080548592906102d6908490610518565b9091555050506001600160a01b03831660009081526003602052604090208054830190555060019392505050565b80600260008282546103169190610500565b90915550506001600160a01b03909116600090815260036020526040902080549091019055565b60036020526000908152604090205481565b600180546101619061052f565b3360009081526003602052604081208054839190839061037d908490610518565b9091555050506001600160a01b0382166000908152600360205260409020805482019055600192915050565b600460209081526000928352604080842090915290825290205481565b80356001600160a01b03811681146103dd57600080fd5b919050565b6000602082840312156103f3578081fd5b6103fc826103c6565b9392505050565b60008060408385031215610415578081fd5b61041e836103c6565b915061042c602084016103c6565b90509250929050565b600080600060608486031215610449578081fd5b610452846103c6565b9250610460602085016103c6565b9150604084013590509250925092565b60008060408385031215610482578182fd5b61048b836103c6565b946020939093013593505050565b901515815260200190565b6000602080835283518082850152825b818110156104d0578581018301518582016040015282016104b4565b818111156104e15783604083870101525b50601f01601f1916929092016040019392505050565b90815260200190565b600082198211156105135761051361056a565b500190565b60008282101561052a5761052a61056a565b500390565b60028104600182168061054357607f821691505b6020821081141561056457634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052601160045260246000fdfea26469706673582212204e53876a7abf080ce7b38dffe1572ec4843a83c565efd2feeb856984b5af6fb764736f6c634300080000330000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000074b616b61726f74000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003534a4e0000000000000000000000000000000000000000000000000000000000",
            "calldata": "70a082310000000000000000000000000000000000000000000000000000000000000001",
            "stack": "",
            "memory": "",
            "return_value": "0000000000000000000000000000000000000000000000000000000000000000",
        },
        "id": "solmate_erc20_balanceOf",
        "marks": [pytest.mark.SolmateERC20],
    },
    {
        "params": {
            "code": "608060405234801561001057600080fd5b5060405161080d38038061080d83398101604081905261002f91610197565b815161004290600090602085019061005e565b50805161005690600190602084019061005e565b505050610248565b82805461006a906101f7565b90600052602060002090601f01602090048101928261008c57600085556100d2565b82601f106100a557805160ff19168380011785556100d2565b828001600101855582156100d2579182015b828111156100d25782518255916020019190600101906100b7565b506100de9291506100e2565b5090565b5b808211156100de57600081556001016100e3565b600082601f830112610107578081fd5b81516001600160401b038082111561012157610121610232565b6040516020601f8401601f191682018101838111838210171561014657610146610232565b604052838252858401810187101561015c578485fd5b8492505b8383101561017d5785830181015182840182015291820191610160565b8383111561018d57848185840101525b5095945050505050565b600080604083850312156101a9578182fd5b82516001600160401b03808211156101bf578384fd5b6101cb868387016100f7565b935060208501519150808211156101e0578283fd5b506101ed858286016100f7565b9150509250929050565b60028104600182168061020b57607f821691505b6020821081141561022c57634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052604160045260246000fd5b6105b6806102576000396000f3fe608060405234801561001057600080fd5b50600436106100935760003560e01c806340c10f191161006657806340c10f19146100fe57806370a082311461011357806395d89b4114610126578063a9059cbb1461012e578063dd62ed3e1461014157610093565b806306fdde0314610098578063095ea7b3146100b657806318160ddd146100d657806323b872dd146100eb575b600080fd5b6100a0610154565b6040516100ad91906104a4565b60405180910390f35b6100c96100c4366004610470565b6101e2565b6040516100ad9190610499565b6100de61024c565b6040516100ad91906104f7565b6100c96100f9366004610435565b610252565b61011161010c366004610470565b610304565b005b6100de6101213660046103e2565b61033d565b6100a061034f565b6100c961013c366004610470565b61035c565b6100de61014f366004610403565b6103a9565b600080546101619061052f565b80601f016020809104026020016040519081016040528092919081815260200182805461018d9061052f565b80156101da5780601f106101af576101008083540402835291602001916101da565b820191906000526020600020905b8154815290600101906020018083116101bd57829003601f168201915b505050505081565b3360008181526004602090815260408083206001600160a01b038716808552925280832085905551919290917f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b9259061023b9086906104f7565b60405180910390a350600192915050565b60025481565b6001600160a01b038316600090815260046020908152604080832033845290915281205460001981146102ae576102898382610518565b6001600160a01b03861660009081526004602090815260408083203384529091529020555b6001600160a01b038516600090815260036020526040812080548592906102d6908490610518565b9091555050506001600160a01b03831660009081526003602052604090208054830190555060019392505050565b80600260008282546103169190610500565b90915550506001600160a01b03909116600090815260036020526040902080549091019055565b60036020526000908152604090205481565b600180546101619061052f565b3360009081526003602052604081208054839190839061037d908490610518565b9091555050506001600160a01b0382166000908152600360205260409020805482019055600192915050565b600460209081526000928352604080842090915290825290205481565b80356001600160a01b03811681146103dd57600080fd5b919050565b6000602082840312156103f3578081fd5b6103fc826103c6565b9392505050565b60008060408385031215610415578081fd5b61041e836103c6565b915061042c602084016103c6565b90509250929050565b600080600060608486031215610449578081fd5b610452846103c6565b9250610460602085016103c6565b9150604084013590509250925092565b60008060408385031215610482578182fd5b61048b836103c6565b946020939093013593505050565b901515815260200190565b6000602080835283518082850152825b818110156104d0578581018301518582016040015282016104b4565b818111156104e15783604083870101525b50601f01601f1916929092016040019392505050565b90815260200190565b600082198211156105135761051361056a565b500190565b60008282101561052a5761052a61056a565b500390565b60028104600182168061054357607f821691505b6020821081141561056457634e487b7160e01b600052602260045260246000fd5b50919050565b634e487b7160e01b600052601160045260246000fdfea26469706673582212204e53876a7abf080ce7b38dffe1572ec4843a83c565efd2feeb856984b5af6fb764736f6c634300080000330000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000074b616b61726f74000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003534a4e0000000000000000000000000000000000000000000000000000000000",
            "calldata": "18160ddd",
            "stack": "",
            "memory": "",
            "return_value": "0000000000000000000000000000000000000000000000000000000000000000",
        },
        "id": "solmate_erc20_totalSupply",
        "marks": [pytest.mark.SolmateERC20],
    },
    {
        "params": {
            "code": "4700",
            "calldata": "",
            "stack": "",
            "memory": "",
            "return_value": "",
        },
        "id": "Get balance of currently executing contract - 0x47 SELFBALANCE",
        "marks": [pytest.mark.SELFBALANCE, pytest.mark.BlockInformation],
    },
]

params_execute = [
    pytest.param(case.pop("params"), **case) for case in test_cases_execute
]
params_execute_at_address = [
    pytest.param(case.pop("params"), **case) for case in test_cases_execute_at_address
]


@pytest.mark.asyncio
class TestZkEVM:
    @staticmethod
    def int_to_uint256(value):
        low = value & ((1 << 128) - 1)
        high = value >> 128
        return low, high

    @pytest.mark.parametrize(
        "params",
        params_execute,
    )
    async def test_execute(self, zk_evm, params):
        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")
        res = await zk_evm.execute(
            code=[int(b, 16) for b in wrap(params["code"], 2)],
            calldata=[int(b, 16) for b in wrap(params["calldata"], 2)],
        ).call(caller_address=1)

        # Print number of steps
        print("Test tx Infos")
        print(res.call_info.execution_resources)

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

    @pytest.mark.parametrize(
        "params",
        params_execute_at_address,
    )
    async def test_execute_at_address(self, zk_evm, eth, params):
        Uint256 = zk_evm.struct_manager.get_contract_struct("Uint256")

        print("DEPLOYING CONTRACT")
        res = await zk_evm.execute_at_address(
            address=0,
            calldata=[int(b, 16) for b in wrap(params["code"], 2)],
        ).execute(caller_address=1)

        print("Contract Deployment tx infos")
        print(res.call_info.execution_resources)

        evm_contract_address = res.result.evm_contract_address
        starknet_contract_address = res.result.starknet_contract_address

        print("INITIATING CONTRACT")
        res = await zk_evm.initiate(
            evm_address=evm_contract_address, starknet_address=starknet_contract_address
        ).execute(caller_address=1)

        print("Contract Initiation tx infos")
        print(res.call_info.execution_resources)

        print("CALLING transactions TX")
        res = await zk_evm.execute_at_address(
            address=evm_contract_address,
            calldata=[int(b, 16) for b in wrap(params["calldata"], 2)],
        ).execute(caller_address=2)

        print("Contract call tx infos")
        print(res.call_info.execution_resources)

        assert res.result.return_data == [
            int(m, 16) for m in wrap(params["return_value"], 2)
        ]

    async def test_deploy(
        self,
        starknet: Starknet,
        zk_evm: StarknetContract,
        contract_account_class: DeclaredClass,
    ):
        code = [1, 12312]
        tx = await zk_evm.deploy(bytes=code).execute(caller_address=1)
        starknet_contract_address = tx.result.starknet_contract_address
        account_contract = StarknetContract(
            starknet.state,
            contract_account_class.abi,
            starknet_contract_address,
            tx,
        )
        assert (await account_contract.code().call()).result.code == code
