// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../components/MainStorage.sol";
import "./MainDispatcherBase.sol";

abstract contract MainDispatcher is MainStorage, MainDispatcherBase {
    uint256 constant SUBCONTRACT_BITS = 4;

    function magicSalt() internal pure virtual returns (uint256);

    function handlerMapSection(uint256 section) internal pure virtual returns (uint256);

    function expectedIdByIndex(uint256 index) internal pure virtual returns (string memory id);

    function validateSubContractIndex(uint256 index, address subContract) internal pure override {
        string memory id = SubContractor(subContract).identify();
        bytes32 hashed_expected_id = keccak256(abi.encodePacked(expectedIdByIndex(index)));
        require(
            hashed_expected_id == keccak256(abi.encodePacked(id)),
            "MISPLACED_INDEX_OR_BAD_CONTRACT_ID"
        );

        // Gets the list of critical selectors from the sub-contract and checks that the selector
        // is mapped to that sub-contract.
        bytes4[] memory selectorsToValidate = SubContractor(subContract).validatedSelectors();

        for (uint256 i = 0; i < selectorsToValidate.length; i++) {
            require(
                getSubContractIndex(selectorsToValidate[i]) == index,
                "INCONSISTENT_DISPATCHER_MAP"
            );
        }
    }

    function handlingContractId(bytes4 selector) external pure virtual returns (string memory id) {
        uint256 index = getSubContractIndex(selector);
        return expectedIdByIndex(index);
    }

    /*
      Returns the index in subContracts where the address of the sub-contract implementing
      the function with the queried selector is held.

      Note: The nature of the sub-contracts handler map is such that all the required selectors
      are mapped. However, other selectors, such that are not implemented in any subcontract,
      may also return a sub-contract address.
      This behavior is by-design, and not a problem.
    */
    function getSubContractIndex(bytes4 selector) internal pure returns (uint256) {
        uint256 location = 0xFF & uint256(keccak256(abi.encodePacked(selector, magicSalt())));
        uint256 offset = (SUBCONTRACT_BITS * location) % 256;

        // We have 64 locations in each register, hence the >> 6 (i.e. location // 64).
        return (handlerMapSection(location >> 6) >> offset) & 0xF;
    }

    /*
      Returns the address of the sub-contract that would be delegated to handle a call
      with the queried selector. (see note above).
    */
    function getSubContract(bytes4 selector) public view override returns (address) {
        return subContracts[getSubContractIndex(selector)];
    }

    function setSubContractAddress(uint256 index, address subContractAddress) internal override {
        subContracts[index] = subContractAddress;
    }
}
