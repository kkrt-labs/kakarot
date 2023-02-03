pragma solidity >=0.8.0;

contract Parent {
    address public child;
    uint256 public count;
    
    function triggerRevert() public {
        child = address(new Child()); 
        count = 1;
        revert("FAIL");
    }

    function inc() public {
        count++;
    }    
}

contract Child {
    uint public value;

    constructor() {
        value = 42;
    }
    
    function doSomething() public pure returns (bool) {
        return true;
    }
}

