pragma solidity =0.5.16;

import "../UniswapV2ERC20.sol";

contract ERC20 is UniswapV2ERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }

    function mint(address to, uint value) external returns (bool) {
        _mint(to, value);
    }
}
