// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

library CairoLib {
    /// @dev The Cairo precompile contract's address.
    address constant CAIRO_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000075001;
    address constant CAIRO_MESSAGING_ADDRESS = 0x0000000000000000000000000000000000075002;

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function callCairo(uint256 contractAddress, uint256 functionSelector, uint256[] memory data)
        internal
        returns (bytes memory returnData)
    {
        bytes memory callData =
            abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        returnData = result;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function callCairo(uint256 contractAddress, uint256 functionSelector) internal returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        return callCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param functionName The name of the Cairo contract function to be called.
    ///
    /// @return returnData The return data from the Cairo contract function.
    function callCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory returnData)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return callCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param functionName The name of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function callCairo(uint256 contractAddress, string memory functionName)
        internal
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return callCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level delegatecall to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @dev Using delegatecall preserves the context of the calling contract, and the execution of the
    /// callee contract is performed using the `msg.sender` of the calling contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function delegatecallCairo(uint256 contractAddress, uint256 functionSelector, uint256[] memory data)
        internal
        returns (bytes memory returnData)
    {
        bytes memory callData =
            abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.delegatecall(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        returnData = result;
    }

    /// @notice Performs a low-level delegatecall to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @dev Using delegatecall preserves the context of the calling contract, and the execution of the
    /// callee contract is performed using the `msg.sender` of the calling contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function delegatecallCairo(uint256 contractAddress, uint256 functionSelector)
        internal
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        return delegatecallCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level delegatecall to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @dev Using delegatecall preserves the context of the calling contract, and the execution of the
    /// callee contract is performed using the `msg.sender` of the calling contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionName The name of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function delegatecallCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        returns (bytes memory returnData)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return delegatecallCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level delegatecall to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @dev Using delegatecall preserves the context of the calling contract, and the execution of the
    /// callee contract is performed using the `msg.sender` of the calling contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionName The name of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function delegatecallCairo(uint256 contractAddress, string memory functionName)
        internal
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return delegatecallCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallCairo(uint256 contractAddress, uint256 functionSelector, uint256[] memory data)
        internal
        view
        returns (bytes memory returnData)
    {
        bytes memory callData =
            abi.encodeWithSignature("call_contract(uint256,uint256,uint256[])", contractAddress, functionSelector, data);

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, string(abi.encodePacked("CairoLib: call_contract failed with: ", result)));

        returnData = result;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallCairo(uint256 contractAddress, uint256 functionSelector)
        internal
        view
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        return staticcallCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionName The name of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallCairo(uint256 contractAddress, string memory functionName, uint256[] memory data)
        internal
        view
        returns (bytes memory returnData)
    {
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return staticcallCairo(contractAddress, functionSelector, data);
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionName The name of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallCairo(uint256 contractAddress, string memory functionName)
        internal
        view
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return staticcallCairo(contractAddress, functionSelector, data);
    }

    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionSelector The function selector of the Cairo class function to be called.
    /// @param data The input data for the Cairo class function.
    /// @return returnData The return data from the Cairo class function.
    function libraryCallCairo(uint256 classHash, uint256 functionSelector, uint256[] memory data)
        internal
        view
        returns (bytes memory returnData)
    {
        bytes memory callData =
            abi.encodeWithSignature("library_call(uint256,uint256,uint256[])", classHash, functionSelector, data);

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: library_call failed");

        returnData = result;
    }

    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionSelector The function selector of the Cairo class function to be called.
    /// @return returnData The return data from the Cairo class function.
    function libraryCallCairo(uint256 classHash, uint256 functionSelector)
        internal
        view
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        return libraryCallCairo(classHash, functionSelector, data);
    }

    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionName The name of the Cairo class function to be called.
    /// @return returnData The return data from the Cairo class function.
    function libraryCallCairo(uint256 classHash, string memory functionName)
        internal
        view
        returns (bytes memory returnData)
    {
        uint256[] memory data = new uint256[](0);
        uint256 functionSelector = uint256(keccak256(bytes(functionName))) % 2 ** 250;
        return libraryCallCairo(classHash, functionSelector, data);
    }

    /// @notice Performs a low-level call to send a message from the Kakarot to the Ethereum network.
    /// @param toAddress The address of the Ethereum contract to send the message to.
    /// @param payload The payload of the message to send to the Ethereum contract. The same payload will need
    /// to be provided on L1 to consume the message.
    function sendMessageToL1(address toAddress, bytes memory payload) internal {
        bytes memory messageData = abi.encode(toAddress, payload);

        (bool success,) = CAIRO_MESSAGING_ADDRESS.call(messageData);
        require(success, "CairoLib: sendMessageToL1 failed");
    }

    /// @notice Converts a Cairo ByteArray to a string
    /// @dev A ByteArray is represented as:
    /**
     * pub struct ByteArray {
     *             data: Array<bytes31>,
     *             pending_word: felt252,
     *             pending_word_len: usize,
     *     }
     *     where `data` is an array of 31-byte packed words, and `pending_word` word of size `pending_word_len`.
     *
     */
    /// @param data The Cairo representation of the ByteArray serialized to bytes.
    function byteArrayToString(bytes memory data) internal pure returns (string memory) {
        require(data.length >= 96, "Invalid byte array length");

        uint256 fullWordsLength;
        uint256 fullWordsPtr;
        uint256 pendingWord;
        uint256 pendingWordLen;

        assembly {
            fullWordsLength := mload(add(data, 32))
            let fullWordsByteLength := mul(fullWordsLength, 32)
            fullWordsPtr := add(data, 64)
            let pendingWordPtr := add(fullWordsPtr, fullWordsByteLength)
            pendingWord := mload(pendingWordPtr)
            pendingWordLen := mload(add(pendingWordPtr, 32))
        }

        require(pendingWordLen <= 31, "Invalid pending word length");

        uint256 totalLength = fullWordsLength * 31 + pendingWordLen;
        bytes memory result = new bytes(totalLength);
        uint256 resultPtr;

        assembly {
            resultPtr := add(result, 32)
            // Copy full words. Because of the Cairo -> Solidity conversion,
            // each full word is 32 bytes long, but contains 31 bytes of information.
            for { let i := 0 } lt(i, fullWordsLength) { i := add(i, 1) } {
                let word := mload(fullWordsPtr)
                let storedWord := shl(8, word)
                mstore(resultPtr, storedWord)
                resultPtr := add(resultPtr, 31)
                fullWordsPtr := add(fullWordsPtr, 32)
            }
            // Copy pending word
            if iszero(eq(pendingWordLen, 0)) { mstore(resultPtr, shl(mul(sub(32, pendingWordLen), 8), pendingWord)) }
        }

        return string(result);
    }
}
