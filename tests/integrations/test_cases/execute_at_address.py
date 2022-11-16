import pytest
from sha3 import keccak_256

test_cases = [
    {
        "params": {
            "value": 0,
            "calldata": "".join(
                [
                    keccak_256("mint(address,uint256)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000001",
                    "0000000000000000000000000000000000000000000000000000000000000164",
                ]
            ),
            "stack": "",
            "memory": "",
            "return_value": "",
        },
        "id": "solmate_erc20_mint",
        "marks": [pytest.mark.SolmateERC20],
    },
    {
        "params": {
            "value": 0,
            "calldata": "".join(
                [
                    keccak_256("balanceOf(address)".encode()).hexdigest()[:8],
                    "0000000000000000000000000000000000000000000000000000000000000001",
                ]
            ),
            "stack": "",
            "memory": "",
            "return_value": "0000000000000000000000000000000000000000000000000000000000000000",
        },
        "id": "solmate_erc20_balanceOf",
        "marks": [pytest.mark.SolmateERC20],
    },
    {
        "params": {
            "value": 0,
            "calldata": keccak_256("totalSupply()".encode()).hexdigest()[:8],
            "stack": "",
            "memory": "",
            "return_value": "0000000000000000000000000000000000000000000000000000000000000000",
        },
        "id": "solmate_erc20_totalSupply",
        "marks": [pytest.mark.SolmateERC20],
    },
]
