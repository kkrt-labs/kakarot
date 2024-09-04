// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

using CairoLib for uint256;

contract BenchmarkCairoCalls {
    /// @dev The cairo contract to call
    uint256 immutable cairoContract;

    uint256 constant MAX_FELT = 0x800000000000011000000000000000000000000000000000000000000000000;

    uint256 constant FUNCTION_SELECTOR_RECEIVE_FELT_INPUTS = uint256(keccak256("receive_felt_inputs")) % 2 ** 250;

    uint256 constant FUNCTION_SELECTOR_PRODUCE_BYTES_OUTPUT = uint256(keccak256("produce_bytes_output")) % 2 ** 250;

    constructor(uint256 cairoContractAddress) {
        cairoContract = cairoContractAddress;
    }

    function empty() external {}

    function callCairoWithFeltInputs(uint32 n_felt_input) external {
        uint256[] memory data = new uint256[](n_felt_input + 1);
        data[0] = n_felt_input;
        for (uint32 i = 1; i <= n_felt_input; i++) {
            data[i] = MAX_FELT;
        }
        cairoContract.callCairo(FUNCTION_SELECTOR_RECEIVE_FELT_INPUTS, data);
    }

    function callCairoWithBytesOutput(uint32 n_felt_output) external {
        uint256[] memory data = new uint256[](1);
        data[0] = n_felt_output;
        bytes memory output = cairoContract.callCairo(FUNCTION_SELECTOR_PRODUCE_BYTES_OUTPUT, data);
        // This is data_len, data from Cairo
        require(output.length == (n_felt_output + 1) * 32, "Invalid output length");
    }
}
