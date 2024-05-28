// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

library CairoLib {
    /// @dev The Cairo precompile contract's address.
    address constant CAIRO_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000075001;

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function callContract(
        uint256 contractAddress,
        uint256 functionSelector,
        uint256[] memory data
    ) internal returns (bytes memory returnData) {
        bytes memory callData = abi.encodeWithSignature(
            "call_contract(uint256,uint256,uint256[])",
            contractAddress,
            functionSelector,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, "CairoLib: call_contract failed");

        returnData = result;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function callContract(
        uint256 contractAddress,
        uint256 functionSelector
    ) internal returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        bytes memory callData = abi.encodeWithSignature(
            "call_contract(uint256,uint256,uint256[])",
            contractAddress,
            functionSelector,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, "CairoLib: call_contract failed");

        returnData = result;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to modify the state of the Cairo contract.
    /// @param functionSelector The name of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function callContract(
        uint256 contractAddress,
        string memory functionSelector
    ) internal returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        bytes memory callData = abi.encodeWithSignature(
            "call_contract(uint256,uint256,uint256[])",
            contractAddress,
            uint256(keccak256(bytes(functionSelector))) % 2**250,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.call(callData);
        require(success, "CairoLib: call_contract failed");

        returnData = result;
    }


    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @param data The input data for the Cairo contract function.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallContract(
        uint256 contractAddress,
        uint256 functionSelector,
        uint256[] memory data
    ) internal view returns (bytes memory returnData) {
        bytes memory callData = abi.encodeWithSignature(
            "call_contract(uint256,uint256,uint256[])",
            contractAddress,
            functionSelector,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: call_contract failed");

        returnData = result;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The function selector of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallContract(
        uint256 contractAddress,
        uint256 functionSelector
    ) internal view returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        bytes memory callData = abi.encodeWithSignature(
            "call_contract(uint256,uint256,uint256[])",
            contractAddress,
            functionSelector,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: call_contract failed");

        returnData = result;
    }

    /// @notice Performs a low-level call to a Cairo contract deployed on the Starknet appchain.
    /// @dev Used with intent to read the state of the Cairo contract.
    /// @param contractAddress The address of the Cairo contract.
    /// @param functionSelector The name of the Cairo contract function to be called.
    /// @return returnData The return data from the Cairo contract function.
    function staticcallContract(
        uint256 contractAddress,
        string memory functionSelector
    ) internal view returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        bytes memory callData = abi.encodeWithSignature(
            "call_contract(uint256,uint256,uint256[])",
            contractAddress,
            uint256(keccak256(bytes(functionSelector))) % 2**250,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: call_contract failed");

        returnData = result;
    }



    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionSelector The function selector of the Cairo class function to be called.
    /// @param data The input data for the Cairo class function.
    /// @return returnData The return data from the Cairo class function.
    function libraryCall(
        uint256 classHash,
        uint256 functionSelector,
        uint256[] memory data
    ) internal view returns (bytes memory returnData) {
        bytes memory callData = abi.encodeWithSignature(
            "library_call(uint256,uint256,uint256[])",
            classHash,
            functionSelector,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: library_call failed");

        returnData = result;
    }

    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionSelector The function selector of the Cairo class function to be called.
    /// @return returnData The return data from the Cairo class function.
    function libraryCall(
        uint256 classHash,
        uint256 functionSelector
    ) internal view returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        bytes memory callData = abi.encodeWithSignature(
            "library_call(uint256,uint256,uint256[])",
            classHash,
            functionSelector,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: library_call failed");

        returnData = result;
    }


    /// @dev Performs a low-level call to a Cairo class declared on the Starknet appchain.
    /// @param classHash The class hash of the Cairo class.
    /// @param functionSelector The name of the Cairo class function to be called.
    /// @return returnData The return data from the Cairo class function.
    function libraryCall(
        uint256 classHash,
        string memory functionSelector
    ) internal view returns (bytes memory returnData) {
        uint256[] memory data = new uint256[](0);
        bytes memory callData = abi.encodeWithSignature(
            "library_call(uint256,uint256,uint256[])",
            classHash,
            uint256(keccak256(bytes(functionSelector))) % 2**250,
            data
        );

        (bool success, bytes memory result) = CAIRO_PRECOMPILE_ADDRESS.staticcall(callData);
        require(success, "CairoLib: library_call failed");

        returnData = result;
    }

}
