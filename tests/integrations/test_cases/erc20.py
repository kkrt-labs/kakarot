import pytest
from sha3 import keccak_256

test_cases = [
    {
        "params": {
            "mint": "".join(
                [
                    keccak_256("mint(address,uint256)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000002",
                    "0000000000000000000000000000000000000000000000000000000000000164",
                ]
            ),
            "approve": "".join(
                [
                    keccak_256("approve(address,uint256)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000001",
                    "00000000000000000000000000000000000000000000000000000000000f4240",
                ]
            ),
            "allowance": "".join(
                [
                    keccak_256("allowance(address,address)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000002",
                    "0000000000000000000000000000000000000000000000000000000000000001",
                ]
            ),
            "transferFrom": "".join(
                [
                    keccak_256(
                        "transferFrom(address,address,uint256)".encode()
                    ).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000002",
                    "0000000000000000000000000000000000000000000000000000000000000001",
                    "000000000000000000000000000000000000000000000000000000000000000a",
                ]
            ),
            "transfer": "".join(
                [
                    keccak_256("transfer(address,uint256)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000003",
                    "0000000000000000000000000000000000000000000000000000000000000005",
                ]
            ),
            "balanceOf": "".join(
                [
                    keccak_256("balanceOf(address)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000001",
                ]
            ),
            "totalSupply": keccak_256("totalSupply()".encode()).hexdigest()[:8],
            "name": keccak_256("name()".encode()).hexdigest()[:8],
            "symbol": keccak_256("symbol()".encode()).hexdigest()[:8],
            "stack": "",
            "memory": "",
            "return_value": "0000000000000000000000000000000000000000000000000000000000000005",
        },
        "id": "solmate_erc20_all_test",
        "marks": [pytest.mark.SolmateERC20],
    },
]
