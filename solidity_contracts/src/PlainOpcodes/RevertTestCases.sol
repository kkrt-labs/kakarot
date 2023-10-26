pragma solidity >=0.8.0;

import "./Counter.sol";

contract ContractRevertsOnMethodCall {
    Counter public counter;
    uint256 public value;

    event PartyTime(bool shouldDance);

    function triggerRevert() public {
        counter = new Counter();
        value = 1;

        emit PartyTime(true);
        revert("FAIL");
    }
}

contract ContractRevertsOnConstruction {
    uint256 public value;

    constructor() {
        value = 42;
        revert("FAIL");
    }
}

contract ContractWithSelfdestructMethod {
    uint256 public count;

    constructor() payable {}

    function inc() public {
        count++;
    }

    function kill() public {
        selfdestruct(payable(msg.sender));
    }
}

contract ContractRevertOnFallbackAndReceive {
    fallback() external payable {
        revert("reverted on fallback");
    }

    receive() external payable {
        revert("reverted on receive");
    }
}
