pragma solidity >=0.8.0;
import "./Counter.sol";

contract ContractRevertsOnMethodCall {
    Counter public counter;
    uint public value;
    event PartyTime(bool shouldDance);    
        
    function triggerRevert() public {
        counter = new Counter(); 
        value = 1;
     
        emit PartyTime(true);        
        revert("FAIL");
    }
}

contract ContractRevertsOnConstruction {
    uint public value;

    constructor() {
        value = 42;
        revert("FAIL");
    }
}

