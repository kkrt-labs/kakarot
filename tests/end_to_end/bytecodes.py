import pytest

from kakarot_scripts.constants import NETWORK

test_cases = [
    {
        "params": {
            "value": 0,
            "code": "604260005260206000F3",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000042",
            "return_data": "0000000000000000000000000000000000000000000000000000000000000042",
            "success": 1,
        },
        "id": "return",
        "marks": [pytest.mark.RETURN, pytest.mark.SystemOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60016001f3",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000000",
            "return_data": "00",
            "success": 1,
        },
        "id": "return2",
        "marks": [pytest.mark.RETURN, pytest.mark.SystemOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60056003600039",
            "calldata": "",
            "stack": "",
            "memory": "0360003900000000000000000000000000000000000000000000000000000000",
            "return_data": "",
            "success": 1,
        },
        "id": "codecopy",
        "marks": [pytest.mark.CODECOPY, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "7dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6008601f600039",
            "calldata": "",
            "stack": "1766847064778384329583297500742918515827483896875618958121606201292619775",
            "memory": "6008601f60003900000000000000000000000000000000000000000000000000",
            "return_data": "",
            "success": 1,
        },
        "id": "codecopy2",
        "marks": [pytest.mark.CODECOPY, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "6003600401600a02608c036102bc04604605600d066010076005600608601060020960040A60600B00",
            "calldata": "",
            "stack": "16",
            "memory": "",
            "return_data": "",
            "success": 1,
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
            "value": 0,
            "code": "60018060036004600260058300",
            "calldata": "",
            "stack": "1,1,3,4,2,5,3",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Duplication operations",
        "marks": [pytest.mark.DUP, pytest.mark.DuplicationOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160001d",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600060011d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f400000000000000000000000000000000000000000000000000000000000000060fe1d",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60f81d",
            "calldata": "",
            "stack": "127",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60fe1d",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160011d",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060011d",
            "calldata": "",
            "stack": "86844066927987146567678238756515930889952488499230423029593188005934847229952",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060ff1d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101001d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101011d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60001d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1d",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SAR",
        "marks": [pytest.mark.SAR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160001b",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600060011b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011b",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639934",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160011b",
            "calldata": "",
            "stack": "2",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160ff1b",
            "calldata": "",
            "stack": "57896044618658097711785492504343953926634992332820282019728792003956564819968",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60016101001b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60016101011b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60001b",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011b",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639934",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1b",
            "calldata": "",
            "stack": "57896044618658097711785492504343953926634992332820282019728792003956564819968",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001b",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHL",
        "marks": [pytest.mark.SHL, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160001c",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6101001c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600060011c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600160011c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060011c",
            "calldata": "",
            "stack": "28948022309329048855892746252171976963317496166410141009864396001978282409984",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f800000000000000000000000000000000000000000000000000000000000000060ff1c",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101001c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7f80000000000000000000000000000000000000000000000000000000000000006101011c",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60001c",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60011c",
            "calldata": "",
            "stack": "57896044618658097711785492504343953926634992332820282019728792003956564819967",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60ff1c",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SHR",
        "marks": [pytest.mark.SHR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "6005600516",
            "calldata": "",
            "stack": "5",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - AND",
        "marks": [pytest.mark.AND, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600a600a146009600a14",
            "calldata": "",
            "stack": "1,0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - EQ",
        "marks": [pytest.mark.EQ, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600a600a116009600a11",
            "calldata": "",
            "stack": "0,1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - GT",
        "marks": [pytest.mark.GT, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600015",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - ISZERO",
        "marks": [pytest.mark.ISZERO, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600a600910600a600a10",
            "calldata": "",
            "stack": "1,0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - LT",
        "marks": [pytest.mark.LT, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600019",
            "calldata": "",
            "stack": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - NOT",
        "marks": [pytest.mark.NOT, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "6005600317",
            "calldata": "",
            "stack": "7",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - OR",
        "marks": [pytest.mark.OR, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff600113",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SGT",
        "marks": [pytest.mark.SGT, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff600112",
            "calldata": "",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Comparison & bitwise logic operations - SLT",
        "marks": [pytest.mark.SLT, pytest.mark.ComparisonBitwiseLogicOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600360026001916004929200",
            "calldata": "",
            "stack": "1,2,3,4",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Exchange operations",
        "marks": [pytest.mark.SWAP, pytest.mark.ExchangeOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "60016101023800",
            "calldata": "",
            "stack": "1,258,7",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Environmental information",
        "marks": [pytest.mark.CODESIZE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "600160024600",
            "calldata": "",
            "stack": f"1,2,{NETWORK['chain_id']}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Block information CHAINID",
        "marks": [pytest.mark.CHAINID, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "4100",
            "calldata": "",
            "stack": f"{0xca40796afb5472abaed28907d5ed6fc74c04954a}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Block information COINBASE",
        "marks": [pytest.mark.COINBASE, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "60016002FE",
            "calldata": "",
            "stack": "1,2",
            "memory": "",
            "return_data": "",
            "success": 0,
        },
        "id": "System operations INVALID",
        "marks": [pytest.mark.INVALID, pytest.mark.SystemOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "4300",
            "calldata": "",
            "stack": "{block_number}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Block information NUMBER",
        "marks": [pytest.mark.NUMBER, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "4200",
            "calldata": "",
            "stack": "{timestamp}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Block information TIMESTAMP",
        "marks": [pytest.mark.TIMESTAMP, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "4700",
            "calldata": "",
            "stack": "0000000000000000000000000000000000000000000000000000000000000000",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get balance of currently executing contract - 0x47 SELFBALANCE",
        "marks": [pytest.mark.SELFBALANCE, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "3200",
            "calldata": "",
            "stack": "{account_address}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Origin Address",
        "marks": [pytest.mark.ORIGIN, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "3300",
            "calldata": "",
            "stack": "{account_address}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Caller Address",
        "marks": [pytest.mark.CALLER, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "610100600052602060002000",
            "calldata": "",
            "stack": "31605475728638136284098257830937953109142906242585568807375082376557418698875",
            "memory": "0000000000000000000000000000000000000000000000000000000000000100",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 32 bytes",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "60106000526001601f2000",
            "calldata": "",
            "stack": "68071607937700842810429351077030899797510977729217708600998965445571406158526",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 1 byte with offset 1f",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "6010600052600160002000",
            "calldata": "",
            "stack": "85131057757245807317576516368191972321038229705283732634690444270750521936266",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 1 byte no offset",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "6010600052600760002000",
            "calldata": "",
            "stack": "101225983456080153511598605893998939348063346639131267901574990367534118792751",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 7 bytes",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "6010600052600860002000",
            "calldata": "",
            "stack": "500549258012437878224561338362079327067368301550791134293299473726337612750",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 8 bytes",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "6010600052600960002000",
            "calldata": "",
            "stack": "78337347954576241567341556127836028920764967266964912349540464394612926403441",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 9 bytes",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "6010600052601160002000",
            "calldata": "",
            "stack": "41382199742381387985558122494590197322490258008471162768551975289239028668781",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
        },
        "id": "Hash 17 bytes",
        "marks": [pytest.mark.SHA3],
    },
    {
        "params": {
            "value": 0,
            "code": "4500",
            "calldata": "",
            "stack": "20000000",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Gas Limit",
        "marks": [pytest.mark.GASLIMIT, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "3d00",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get the size of return data - 0x3d RETURNDATASIZE",
        "marks": [pytest.mark.RETURNDATASIZE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "600a4400",
            "calldata": "",
            "stack": "10,0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Load Word from Memory",
        "marks": [pytest.mark.DIFFICULTY, pytest.mark.BlockInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "4800",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get baseFee",
        "marks": [
            pytest.mark.BASEFEE,
            pytest.mark.BlockInformation,
        ],
    },
    {
        "params": {
            "code": "34",
            "calldata": "",
            "value": 90,
            "stack": "90",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get deposited value by the instruction/transaction responsible for this execution - 0x34 CALLVALUE",
        "marks": [pytest.mark.CALLVALUE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "600035",
            "calldata": "000000000000000000000000000000000000000000000000000000000000000a",
            "stack": "10",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Load CallData onto the Stack - 0x35 CALLDATALOAD",
        "marks": [pytest.mark.CALLDATALOAD, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "3600",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get the size of calldata when empty calldata - 0x36 CALLDATASIZE",
        "marks": [pytest.mark.CALLDATASIZE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "3600",
            "calldata": "ff",
            "stack": "1",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get the size of calldata when non empty calldata - 0x36 CALLDATASIZE",
        "marks": [pytest.mark.CALLDATASIZE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "60013100",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Balance",
        "marks": [pytest.mark.BALANCE, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "600a60005200",
            "calldata": "",
            "stack": "",
            "memory": "000000000000000000000000000000000000000000000000000000000000000a",
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations",
        "marks": [pytest.mark.MSTORE, pytest.mark.StackMemoryStorageFlowOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600a60015200",
            "calldata": "",
            "stack": "",
            "memory": "00000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000",
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations",
        "marks": [pytest.mark.MSTORE, pytest.mark.StackMemoryStorageFlowOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600a60005260fa60245200",
            "calldata": "",
            "stack": "",
            "memory": (
                "000000000000000000000000000000000000000000000000000000000000000a"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "000000fa00000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations",
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "58600158",
            "calldata": "",
            "stack": "0,1,3",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operation - PC",
        "marks": [pytest.mark.PC, pytest.mark.StackMemoryStorageFlowOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "5900",
            "calldata": "",
            "stack": "0",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get Memory Size",
        "marks": [pytest.mark.MSIZE, pytest.mark.StackMemoryStorageFlowOperations],
    },
    {
        "params": {
            "value": 0,
            "code": "600a600052600051",
            "calldata": "",
            "stack": "10",
            "memory": "000000000000000000000000000000000000000000000000000000000000000a",
            "return_data": "",
            "success": 1,
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
            "value": 0,
            "code": "5860015b6001600158",
            "calldata": "",
            "stack": "0,1,1,1,8",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Jumpdest opcode",
        "marks": [
            pytest.mark.JUMPDEST,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "600556600a5b600b",
            "calldata": "",
            "stack": "11",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "JUMP opcode",
        "marks": [
            pytest.mark.JUMP,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "6001600757600a5b600a6000600857600a01",
            "calldata": "",
            "stack": "20",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "JUMP if condition is met",
        "marks": [
            pytest.mark.JUMPI,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "601160405200",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000011"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations - Check very large offsets",
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "6011604052602260405200",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000022"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations - Check Colliding offsets",
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7d111111111111111111111111111111111111111111111111111111111111600052",
            "calldata": "",
            "stack": "",
            "memory": "0000111111111111111111111111111111111111111111111111111111111111",
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations - Check saving memory with 30 bytes",
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff604052601160355200",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "000000000000000000000000000000000000000011ffffffffffffffffffffff"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations - Check saving memory in between an already saved memory location",
        "marks": [
            pytest.mark.MSTORE,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "611122600353",
            "calldata": "",
            "stack": "",
            "memory": "0000002200000000000000000000000000000000000000000000000000000000",
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations - Check saving memory in between an already saved memory location",
        "marks": [
            pytest.mark.MSTORE8,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7f111111111111111111111111111111111111111111111111111111111111111160005261222260055300",
            "calldata": "",
            "stack": "",
            "memory": "1111111111221111111111111111111111111111111111111111111111111111",
            "return_data": "",
            "success": 1,
        },
        "id": "Memory operations - Check saving memory in between an already saved memory location",
        "marks": [
            pytest.mark.MSTORE8,
            pytest.mark.StackMemoryStorageFlowOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "6020600560063700",
            "calldata": "00112233445566778899aabbcceeddff",
            "stack": "",
            "memory": (
                "0000000000005566778899aabbcceeddff000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "calldatacopy",
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7f00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff60005260106003600337",
            "calldata": "11111111111111111111111111111111111111111111111111111111111111111111",
            "stack": "",
            "memory": "0011221111111111111111111111111111111133445566778899aabbccddeeff",
            "return_data": "",
            "success": 1,
        },
        "id": "calldatacopy1",
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60246005600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": (
                "5566778899aabbcceeddff00112233445566778899aabbccddeeff0000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "calldatacopy2",
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60206005600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": "5566778899aabbcceeddff00112233445566778899aabbccddeeff0011223344",
            "return_data": "",
            "success": 1,
        },
        "id": "calldatacopy3",
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60406003600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": (
                "33445566778899aabbcceeddff00112233445566778899aabbccddeeff001122"
                "33445566778899aabbccddeeff00000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "calldatacopy4",
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60106005600037",
            "calldata": "00112233445566778899aabbcceeddff00112233445566778899aabbccddeeff",
            "stack": "",
            "memory": "5566778899aabbcceeddff001122334400000000000000000000000000000000",
            "return_data": "",
            "success": 1,
        },
        "id": "calldatacopy5",
        "marks": [
            pytest.mark.CALLDATACOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60106000526001601fA000",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
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
            "value": 0,
            "code": "601060005260016022A000",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000010"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
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
            "value": 0,
            "code": "60106000527FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF6001601fA100",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
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
            "value": 0,
            "code": "601060005260FF60016022A100",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000010"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
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
            "value": 0,
            "code": "60106000527FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF60FF6001601fA200",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
            "events": [
                [
                    [
                        0xFF,
                        0x00,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
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
            "value": 0,
            "code": "6010600052600060FF60016022A200",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000010"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
            "events": [[[0xFF, 0x00, 0x00, 0x00], [0x00]]],
        },
        "id": "PRElog2-1",
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "601060005260AB7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF60FF6001601fA300",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
            "events": [
                [
                    [
                        0xFF,
                        0x00,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xAB,
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
            "value": 0,
            "code": "601060005260AB600060FF60016022A300",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000010"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
            "events": [[[0xFF, 0x00, 0x00, 0x00, 0xAB, 0x00], [0x00]]],
        },
        "id": "PRElog3-1",
        "marks": [
            pytest.mark.LOG,
            pytest.mark.LoggingOperations,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "6010600052600860AB7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF60FF6001601fA400",
            "calldata": "",
            "stack": "",
            "memory": "0000000000000000000000000000000000000000000000000000000000000010",
            "return_data": "",
            "success": 1,
            "events": [
                [
                    [
                        0xFF,
                        0x00,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                        0xAB,
                        0x00,
                        0x08,
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
            "value": 0,
            "code": "6010600052600860AB600060FF60016022A400",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000010"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
            "events": [[[0xFF, 0x00, 0x00, 0x00, 0xAB, 0x00, 0x08, 0x00], [0x00]]],
        },
        "id": "PRElog4-1",
    },
    {
        "params": {
            "value": 0,
            "code": "60026000600039",
            "calldata": "",
            "stack": "",
            "memory": "6002000000000000000000000000000000000000000000000000000000000000",
            "return_data": "",
            "success": 1,
        },
        "id": "Environment Information - CODECOPY (0x39) - code slice within bounds, memory offset > len with tail padding",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7d00112233445566778899aabbccddeeff00112233445566778899aabbccdd60005260086003600139",
            "calldata": "",
            "stack": "",
            "memory": "002233445566778899778899aabbccddeeff00112233445566778899aabbccdd",
            "return_data": "",
            "success": 1,
        },
        "id": "Environmental Information - CODECOPY (0x39) - code slice within bounds, memory copy within bounds",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7d00112233445566778899aabbccddeeff00112233445566778899aabbccdd60005260206003600139",
            "calldata": "",
            "stack": "",
            "memory": (
                "002233445566778899aabbccddeeff00112233445566778899aabbccdd600052"
                "6000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Environmental Information - CODECOPY (0x39) - code slice within bounds, memory offset < len < offset + size",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60386002600339",
            "calldata": "",
            "stack": "",
            "memory": (
                "0000006002600339000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Environmental Information - CODECOPY (0x39) - code with padding + memory offset > len ",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7d00112233445566778899aabbccddeeff00112233445566778899aabbccdd60005260056065600439",
            "calldata": "",
            "stack": "",
            "memory": "000000110000000000778899aabbccddeeff00112233445566778899aabbccdd",
            "return_data": "",
            "success": 1,
        },
        "id": "Environmental Information - CODECOPY (0x39) - code offset > len, memory offset + size < len",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7dFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F0000000000000000000000000000000000000000000000000000000000000000505060326000600039",
            "calldata": "",
            "stack": "",
            "memory": (
                "7dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Environment Information - CODECOPY (0x39) - evmcode example 1",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7dFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7F00000000000000000000000000000000000000000000000000000000000000005050603260006000396008601f600039",
            "calldata": "",
            "stack": "",
            "memory": (
                "7f00000000000000ffffffffffffffffffffffffffffffffffffffffffffff7f"
                "0000000000000000000000000000000000000000000000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Environment Information - CODECOPY (0x39) - evmcode example 1+2",
        "marks": [
            pytest.mark.CODECOPY,
            pytest.mark.EnvironmentalInformation,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "3000",
            "calldata": "",
            "stack": f"""{int.from_bytes(b"target_evm_address", "big")}""",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "Get address of currently executing account - 0x30 ADDRESS",
        "marks": [pytest.mark.ADDRESS, pytest.mark.EnvironmentalInformation],
    },
    {
        "params": {
            "value": 0,
            "code": "7f456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3600052601c6020527f9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac80388256086040527f4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852ada6060526020608060806000600163fffffffffa50608051",
            "calldata": "",
            "stack": str(int("7156526fbd7a3c72969b54f64e42c10fbb768c8a", 16)),
            "memory": (
                "456e9aea5e197a1f1af7a3e85a3212fa4049a3ba34c2289b4c860fc0b0c64ef3"
                "000000000000000000000000000000000000000000000000000000000000001c"
                "9242685bf161793cc25603c231bc2f568eb630ea16aa137d2664ac8038825608"
                "4f8ae3bd7535248d0bd448298cc2e2071e56992d0774dc340c368ae950852ada"
                "0000000000000000000000007156526fbd7a3c72969b54f64e42c10fbb768c8a"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - EC_RECOVER - playground test case",
        "marks": [pytest.mark.EC_RECOVER, pytest.mark.Precompiles],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff600052602060206001601f600363fffffffffa50602051",
            "calldata": "",
            "stack": str(0x2C0C45D3ECAB80FE060E5F1D7057CD2F8DE5E557),
            "memory": (
                "00000000000000000000000000000000000000000000000000000000000000ff"
                "0000000000000000000000002c0c45d3ecab80fe060e5f1d7057cd2f8de5e557"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - RIPEMD160 - playground test case",
        "marks": [pytest.mark.RIPEMD160, pytest.mark.Precompiles],
    },
    {
        "params": {
            "value": 0,
            "code": "60016000526002602052600160405260026060526040608060806000600663fffffffffa5060a051608051",
            "calldata": "",
            "stack": f"{0x15ED738C0E0A7C92E7845F96B2AE9C0A68A6A449E3538FC7FF3EBF7A5A18A2C4},{0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD3}",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000001"
                "0000000000000000000000000000000000000000000000000000000000000002"
                "0000000000000000000000000000000000000000000000000000000000000001"
                "0000000000000000000000000000000000000000000000000000000000000002"
                "030644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd3"
                "15ed738c0e0a7c92e7845f96b2ae9c0a68a6a449e3538fc7ff3ebf7a5a18a2c4"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - EC_ADD - playground test case",
        "marks": [
            pytest.mark.EC_ADD,
            pytest.mark.Precompiles,
            pytest.mark.xfail(reason="Hint is not whitelisted"),
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "6001600052600160205260016040527F08090a00000000000000000000000000000000000000000000000000000000006060526001609f60636000600563fffffffffa50608051",
            "calldata": "",
            "stack": f"{0x8}",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000001"
                "0000000000000000000000000000000000000000000000000000000000000001"
                "0000000000000000000000000000000000000000000000000000000000000001"
                "08090a0000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000008"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - ModExp - playground test case",
        "marks": [
            pytest.mark.MOD_EXP,
            pytest.mark.Precompiles,
            pytest.mark.xfail(reason="Hint is not whitelisted"),
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "6001600052600260205260026040526040606060606000600763fffffffffa50608051606051",
            "calldata": "",
            "stack": f"{0x15ED738C0E0A7C92E7845F96B2AE9C0A68A6A449E3538FC7FF3EBF7A5A18A2C4},{0x30644E72E131A029B85045B68181585D97816A916871CA8D3C208C16D87CFD3}",
            "memory": (
                "0000000000000000000000000000000000000000000000000000000000000001"
                "0000000000000000000000000000000000000000000000000000000000000002"
                "0000000000000000000000000000000000000000000000000000000000000002"
                "030644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd3"
                "15ed738c0e0a7c92e7845f96b2ae9c0a68a6a449e3538fc7ff3ebf7a5a18a2c4"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - EC_MUL - playground test case",
        "marks": [
            pytest.mark.EC_MUL,
            pytest.mark.Precompiles,
            pytest.mark.xfail(reason="Hint is not whitelisted"),
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "7f0000000c48c9bdf267e6096a3ba7ca8485ae67bb2bf894fe72f36e3cf1361d5f6000527f3af54fa5d182e6ad7f520e511f6c3e2b8c68059b6bbd41fbabd9831f79217e136020527f19cde05b6162630000000000000000000000000000000000000000000000000060405260006060526000608052600060a0527f000000000300000000000000000000000000000001000000000000000000000060c0526040600060d560006009630000000cfa50600051602051",
            "calldata": "",
            "stack": f"{0xba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1},{0x7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923}",
            "memory": (
                "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d1"
                "7d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923"
                "19cde05b61626300000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000000000000000000000000000000000000000000000000000000000000"
                "0000000003000000000000000000000000000000010000000000000000000000"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - BLAKE2F - playground test case",
        "marks": [pytest.mark.BLAKE2F, pytest.mark.Precompiles],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff600052602060206001601f600263fffffffffa50602051",
            "calldata": "",
            "stack": str(
                0xA8100AE6AA1940D0B663BB31CD466142EBBDBD5187131B92D93818987832EB89
            ),
            "memory": (
                "00000000000000000000000000000000000000000000000000000000000000ff"
                "a8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89"
            ),
            "return_data": "",
            "success": 1,
        },
        "id": "Precompiles - SHA2-256 - playground test case",
        "marks": [
            pytest.mark.SHA256,
            pytest.mark.Precompiles,
        ],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff60aa55",
            "calldata": "",
            "stack": "",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "SSTORE 0xff at key 0xaa",
        "marks": [pytest.mark.SSTORE],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff60aa5560aa54",
            "calldata": "",
            "stack": f"{0xff}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "SSTORE 0xff at key 0xaa, then SLOAD 0xaa",
        "marks": [pytest.mark.SSTORE, pytest.mark.SLOAD],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff60aa55",
            "calldata": "",
            "stack": "",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "TSTORE 0xff at key 0xaa",
        "marks": [pytest.mark.TSTORE],
    },
    {
        "params": {
            "value": 0,
            "code": "60ff60aa5560aa54",
            "calldata": "",
            "stack": f"{0xff}",
            "memory": "",
            "return_data": "",
            "success": 1,
        },
        "id": "SSTORE 0xff at key 0xaa, then SLOAD 0xaa",
        "marks": [pytest.mark.TSTORE, pytest.mark.TLOAD],
    },
]
