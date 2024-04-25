pragma solidity =0.5.16;

import "../UniswapV2ERC20.sol";

contract ERC20 is UniswapV2ERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}

// TODO: Fix address collision if token_a and token_b fixtures both use UniswapV2/ERC20.sol::ERC20
contract ERC20Bis is UniswapV2ERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
