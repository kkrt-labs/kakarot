pragma solidity >=0.8.0;

contract Parent {
    address public child;
    uint256 public count;
    event PartyTime(bool shouldDance);    

    function commencePartyTime() public {
       emit PartyTime(true);
    }
    
    function triggerRevert() public {
        child = address(new Child()); 
        count = 1;
        count = 2;
        count = 0;
        count = 1;
        emit PartyTime(true);        
        revert("FAIL");
    }

    function inc() public {
        count++;
    }    
}

contract ContractRevertsOnConstruction {
    uint public value;

    constructor() {
        value = 42;
        revert("FAIL");
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

