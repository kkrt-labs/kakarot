// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

/*
  Common Utility librarries.
  I. Addresses (extending address).
*/
library Addresses {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function performEthTransfer(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}(""); // NOLINT: low-level-calls.
        require(success, "ETH_TRANSFER_FAILED");
    }

    /*
      Safe wrapper around ERC20/ERC721 calls.
      This is required because many deployed ERC20 contracts don't return a value.
      See https://github.com/ethereum/solidity/issues/4116.
    */
    function safeTokenContractCall(address tokenAddress, bytes memory callData) internal {
        require(isContract(tokenAddress), "BAD_TOKEN_ADDRESS");
        // NOLINTNEXTLINE: low-level-calls.
        (bool success, bytes memory returndata) = tokenAddress.call(callData);
        require(success, string(returndata));

        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "TOKEN_OPERATION_FAILED");
        }
    }

    /*
      Validates that the passed contract address is of a real contract,
      and that its id hash (as infered fromn identify()) matched the expected one.
    */
    function validateContractId(address contractAddress, bytes32 expectedIdHash) internal {
        require(isContract(contractAddress), "ADDRESS_NOT_CONTRACT");
        (bool success, bytes memory returndata) = contractAddress.call( // NOLINT: low-level-calls.
            abi.encodeWithSignature("identify()")
        );
        require(success, "FAILED_TO_IDENTIFY_CONTRACT");
        string memory realContractId = abi.decode(returndata, (string));
        require(
            keccak256(abi.encodePacked(realContractId)) == expectedIdHash,
            "UNEXPECTED_CONTRACT_IDENTIFIER"
        );
    }
}

/*
  II. StarkExTypes - Common data types.
*/
library StarkExTypes {
    // Structure representing a list of verifiers (validity/availability).
    // A statement is valid only if all the verifiers in the list agree on it.
    // Adding a verifier to the list is immediate - this is used for fast resolution of
    // any soundness issues.
    // Removing from the list is time-locked, to ensure that any user of the system
    // not content with the announced removal has ample time to leave the system before it is
    // removed.
    struct ApprovalChainData {
        address[] list;
        // Represents the time after which the verifier with the given address can be removed.
        // Removal of the verifier with address A is allowed only in the case the value
        // of unlockedForRemovalTime[A] != 0 and unlockedForRemovalTime[A] < (current time).
        mapping(address => uint256) unlockedForRemovalTime;
    }
}
