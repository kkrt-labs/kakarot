// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./CairoLib.sol";

using CairoLib for uint256;

contract PragmaCaller {
    /// @dev The starknet address of the pragma oracle
    uint256 pragmaOracle;

    /// @dev The cairo function selector to call - `get_data_median`
    uint256 constant FUNCTION_SELECTOR_GET_DATA_MEDIAN = uint256(keccak256("get_data_median")) % 2 ** 250;

    struct PragmaPricesResponse {
        uint256 price;
        uint256 decimals;
        uint256 last_updated_timestamp;
        uint256 num_sources_aggregated;
        uint256 maybe_expiration_timestamp;
    }

    enum DataType {
        SpotEntry,
        FuturesEntry,
        GenericEntry
    }

    struct DataRequest {
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
    }

    constructor(uint256 pragmaOracleAddress) {
        pragmaOracle = pragmaOracleAddress;
    }

    function getDataMedianSpot(DataRequest memory request) public view returns (PragmaPricesResponse memory response) {
        // Serialize the data request into a format compatible with the expected Pragma inputs - [enumIndex, [variantValues...]
        // expirationTimestamp is only used for FuturesEntry requests - skip it for SpotEntry requests and GenericEntry requests
        uint256[] memory data = new uint256[](request.dataType == DataType.FuturesEntry ? 3 : 2);
        data[0] = uint256(request.dataType);
        data[1] = request.pairId;
        if (request.dataType == DataType.FuturesEntry) {
            data[2] = request.expirationTimestamp;
        }

        bytes memory returnData = pragmaOracle.staticcallCairo(FUNCTION_SELECTOR_GET_DATA_MEDIAN, data);

        assembly {
            // Load the values from the return data
            // returnData[0:32] is the length of the return data
            let price := mload(add(returnData, 0x20))
            let decimals := mload(add(returnData, 0x40))
            let last_updated_timestamp := mload(add(returnData, 0x60))
            let num_sources_aggregated := mload(add(returnData, 0x80))

            // If the data never expires, the expiration timestamp is not included in the return data
            // and we set it to 0 - otherwise, we load it from the return data
            let never_expires := mload(add(returnData, 0xa0))
            let maybe_expiration_timestamp := 0
            if eq(never_expires, 0) { maybe_expiration_timestamp := mload(add(returnData, 0xc0)) }

            // Store the values in the response struct
            mstore(response, price)
            mstore(add(response, 0x20), decimals)
            mstore(add(response, 0x40), last_updated_timestamp)
            mstore(add(response, 0x60), num_sources_aggregated)
            mstore(add(response, 0x80), maybe_expiration_timestamp)
        }
        return response;
    }
}
