# Support of Counter contract opcodes for the MVP

```solidity
pragma solidity ^0.8.3;

contract Counter {
    uint public count;

    // Function to get the current count
    function get() public view returns (uint) {
        return count;
    }

    // Function to increment count by 1
    function inc() public {
        count += 1;
    }

    // Function to decrement count by 1
    function dec() public {
        count -= 1;
    }
}
```

35 / 44 opcodes are supported by the MVP.

| Opcode Name  | Implemented |
| ------------ | ----------- |
| STOP         | ✅          |
| ADD          | ✅          |
| SUB          | ✅          |
| MOD          | ✅          |
| LT           | ✅          |
| GT           | ✅          |
| SLT          | ✅          |
| EQ           | ✅          |
| ISZERO       | ✅          |
| SHR          | ✅          |
| KECCAK256    | ✅          |
| CALLVALUE    |             |
| CALLDATALOAD | ✅          |
| CALLDATASIZE | ✅          |
| CALLDATACOPY |             |
| CODECOPY     |             |
| POP          | ✅          |
| MSTORE       | ✅          |
| MLOAD        | ✅          |
| SLOAD        |             |
| SSTORE       |             |
| JUMP         | ✅          |
| JUMPI        | ✅          |
| JUMPDEST     | ✅          |
| PUSH1        | ✅          |
| PUSH2        | ✅          |
| PUSH4        | ✅          |
| PUSH5        | ✅          |
| PUSH13       | ✅          |
| PUSH27       | ✅          |
| PUSH29       | ✅          |
| PUSH32       | ✅          |
| DUP1         | ✅          |
| DUP2         | ✅          |
| DUP3         | ✅          |
| DUP4         | ✅          |
| DUP5         | ✅          |
| DUP6         | ✅          |
| SWAP1        | ✅          |
| SWAP2        | ✅          |
| SWAP3        | ✅          |
| LOG2         |             |
| RETURN       |             |
| REVERT       |             |
| INVALID      | ✅          |
