// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

interface ICounter {
    function count() external view returns (uint256);

    function inc() external;

    function dec() external;

    function reset() external;
}

/// @notice Contract for integration testing of EVM opcodes.
/// @author Kakarot9000
/// @dev Add functions and storage variables for opcodes accordingly.
contract PlainOpcodes {
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/
    ICounter counter;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address counterAddress) {
        counter = ICounter(counterAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS FOR OPCODES
    //////////////////////////////////////////////////////////////*/
    function opcodeBlockHash(
        uint256 blockNumber
    ) public view returns (bytes32 _blockhash) {
        return (blockhash(blockNumber));
    }

    function opcodeAddress() public view returns (address selfAddress) {
        return (address(this));
    }

    function opcodeStaticCall() public view returns (uint256) {
        return counter.count();
    }

    function opcodeStaticCall2() public view returns (bool, bytes memory) {
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("inc()")));
        return address(counter).staticcall(data);
    }

    function opcodeCall() public {
        counter.inc();
    }
}
