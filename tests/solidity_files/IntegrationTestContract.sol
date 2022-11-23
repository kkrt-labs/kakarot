// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Contract for integration testing of EVM opcodes.
/// @author Kakarot9000 
/// @dev Do add functions and storage variables for opcodes accordingly.
contract IntegrationTestContract {
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONS FOR OPCODES
    //////////////////////////////////////////////////////////////*/
    function opcodeAddress()
        public
        view
        returns (address selfAddress) 
    {
        return (address(this));
    }
}
