// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {CairoLib} from "kakarot-lib/CairoLib.sol";

using CairoLib for uint256;

/// @notice Contract for interacting with Pragma's Oracle on Starknet. This include the main contract
///         and the summary stats contract.
/// @dev Use this contract to call Pragma's function.
contract PragmaCaller {
    /// @dev The cairo function selector to call `get_data` from the Pragma Oracle
    uint256 private constant FUNCTION_SELECTOR_GET_DATA = uint256(keccak256("get_data")) % 2 ** 250;

    /// @dev The cairo function selector to call `calculate_mean` from the Pragma Summary Stats
    uint256 private constant FUNCTION_SELECTOR_CALCULATE_MEAN = uint256(keccak256("calculate_mean")) % 2 ** 250;

    /// @dev The cairo function selector to call `calculate_volatility` from the Pragma Summary Stats
    uint256 private constant FUNCTION_SELECTOR_CALCULATE_VOLATILITY =
        uint256(keccak256("calculate_volatility")) % 2 ** 250;

    /// @dev The cairo function selector to call `calculate_twap` from the Pragma Summary Stats
    uint256 private constant FUNCTION_SELECTOR_CALCULATE_TWAP = uint256(keccak256("calculate_twap")) % 2 ** 250;

    /// @dev The starknet address of the pragma oracle
    uint256 private immutable pragmaOracle;

    /// @dev The starknet address of the pragma summary stats
    uint256 private immutable pragmaSummaryStats;

    /// @dev The aggregation mode used by the Oracle
    enum AggregationMode {
        Median,
        Mean
    }

    /// @dev The request data type
    enum DataType {
        SpotEntry,
        FuturesEntry,
        GenericEntry
    }

    struct PragmaPricesRequest {
        AggregationMode aggregationMode;
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
    }

    struct PragmaPricesResponse {
        uint256 price;
        uint256 decimals;
        uint256 last_updated_timestamp;
        uint256 num_sources_aggregated;
        uint256 maybe_expiration_timestamp;
    }

    struct PragmaCalculateMeanRequest {
        AggregationMode aggregationMode;
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
        uint64 startTimestamp;
        uint64 endTimestamp;
    }

    struct PragmaCalculateVolatilityRequest {
        AggregationMode aggregationMode;
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
        uint64 startTimestamp;
        uint64 endTimestamp;
        uint64 numSamples;
    }

    struct PragmaCalculateTwapRequest {
        AggregationMode aggregationMode;
        DataType dataType;
        uint256 pairId;
        uint256 expirationTimestamp;
        uint64 startTimestamp;
        uint64 durationInSeconds;
    }

    struct PragmaSummaryStatsResponse {
        uint256 price;
        uint256 decimals;
    }

    /// @dev Constructor sets the oracle & summary stats addresses.
    constructor(uint256 pragmaOracleAddress, uint256 pragmaSummaryStatsAddress) {
        require(pragmaOracleAddress != 0, "Invalid Pragma Oracle address");
        require(pragmaSummaryStatsAddress != 0, "Invalid Pragma Summary Stats address");
        pragmaOracle = pragmaOracleAddress;
        pragmaSummaryStats = pragmaSummaryStatsAddress;
    }

    /// @notice Calls the `get_data` function from the Pragma's Oracle contract on Starknet.
    /// @param request The request parameters to fetch Pragma's Prices. See `PragmaPricesRequest`.
    /// @return response The pragma prices response of the specified request.
    function getData(PragmaPricesRequest memory request) public view returns (PragmaPricesResponse memory response) {
        bool isFuturesData = request.dataType == DataType.FuturesEntry;

        // Serialize the data request into a format compatible with the expected Pragma inputs
        uint256[] memory data = new uint256[](isFuturesData ? 4 : 3);
        data[0] = uint256(request.dataType);
        data[1] = request.pairId;
        if (isFuturesData) {
            data[2] = request.expirationTimestamp;
            data[3] = uint256(request.aggregationMode);
        } else {
            data[2] = uint256(request.aggregationMode);
        }

        bytes memory returnData = pragmaOracle.staticcallCairo(FUNCTION_SELECTOR_GET_DATA, data);

        // 160 = 5 felts for Spot/Generic data ; 192 = 6 felts for Futures.
        uint256 expectedLength = isFuturesData ? 192 : 160;
        require(returnData.length == expectedLength, "Invalid return data length.");

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

    /// @notice Calls the `calculate_mean` function from the Pragma's Summary Stats contract on Starknet.
    /// @param request The request parameters of `calculate_mean`. See `PragmaCalculateMeanRequest`.
    /// @return response The return of the mean calculation, i.e the price and the decimals. See `PragmaSummaryStatsResponse`.
    function calculateMean(PragmaCalculateMeanRequest memory request)
        public
        view
        returns (PragmaSummaryStatsResponse memory response)
    {
        // Serialize the data request into a format compatible with the expected Pragma inputs
        uint256[] memory data = new uint256[](request.dataType == DataType.FuturesEntry ? 6 : 5);
        data[0] = uint256(request.dataType);
        data[1] = request.pairId;
        if (request.dataType == DataType.FuturesEntry) {
            data[2] = request.expirationTimestamp;
            data[3] = request.startTimestamp;
            data[4] = request.endTimestamp;
            data[5] = uint256(request.aggregationMode);
        } else {
            data[2] = request.startTimestamp;
            data[3] = request.endTimestamp;
            data[4] = uint256(request.aggregationMode);
        }

        bytes memory returnData = pragmaSummaryStats.staticcallCairo(FUNCTION_SELECTOR_CALCULATE_MEAN, data);
        require(returnData.length == 64, "Invalid return data length."); // 64 = 2 felts.

        assembly {
            // Load the values from the return data
            // returnData[0:32] is the length of the return data
            let price := mload(add(returnData, 0x20))
            let decimals := mload(add(returnData, 0x40))

            // Store the values in the response struct
            mstore(response, price)
            mstore(add(response, 0x20), decimals)
        }
        return response;
    }

    /// @notice Calls the `calculate_volatility` function from the Pragma's Summary Stats contract on Starknet.
    /// @param request The request parameters of `calculate_volatility`. See `PragmaCalculateVolatilityRequest`.
    /// @return response The return of the volatility calculation, i.e the price and the decimals. See `PragmaSummaryStatsResponse`.
    function calculateVolatility(PragmaCalculateVolatilityRequest memory request)
        public
        view
        returns (PragmaSummaryStatsResponse memory response)
    {
        // Serialize the data request into a format compatible with the expected Pragma inputs
        uint256[] memory data = new uint256[](request.dataType == DataType.FuturesEntry ? 7 : 6);
        data[0] = uint256(request.dataType);
        data[1] = request.pairId;
        if (request.dataType == DataType.FuturesEntry) {
            data[2] = request.expirationTimestamp;
            data[3] = request.startTimestamp;
            data[4] = request.endTimestamp;
            data[5] = request.numSamples;
            data[6] = uint256(request.aggregationMode);
        } else {
            data[2] = request.startTimestamp;
            data[3] = request.endTimestamp;
            data[4] = request.numSamples;
            data[5] = uint256(request.aggregationMode);
        }

        bytes memory returnData = pragmaSummaryStats.staticcallCairo(FUNCTION_SELECTOR_CALCULATE_VOLATILITY, data);
        require(returnData.length == 64, "Invalid return data length."); // 64 = 2 felts.

        assembly {
            // Load the values from the return data
            // returnData[0:32] is the length of the return data
            let price := mload(add(returnData, 0x20))
            let decimals := mload(add(returnData, 0x40))

            // Store the values in the response struct
            mstore(response, price)
            mstore(add(response, 0x20), decimals)
        }
        return response;
    }

    /// @notice Calls the `calculate_twap` function from the Pragma's Summary Stats contract on Starknet.
    /// @param request The request parameters of `calculate_twap`. See `PragmaCalculateTwapRequest`.
    /// @return response The return of the twap calculation, i.e the price and the decimals. See `PragmaSummaryStatsResponse`.
    function calculateTwap(PragmaCalculateTwapRequest memory request)
        public
        view
        returns (PragmaSummaryStatsResponse memory response)
    {
        // Serialize the data request into a format compatible with the expected Pragma inputs
        uint256[] memory data = new uint256[](request.dataType == DataType.FuturesEntry ? 6 : 5);
        data[0] = uint256(request.dataType);
        data[1] = request.pairId;
        if (request.dataType == DataType.FuturesEntry) {
            data[2] = request.expirationTimestamp;
            data[3] = uint256(request.aggregationMode);
            data[4] = request.startTimestamp;
            data[5] = request.durationInSeconds;
        } else {
            data[2] = uint256(request.aggregationMode);
            data[3] = request.startTimestamp;
            data[4] = request.durationInSeconds;
        }

        bytes memory returnData = pragmaSummaryStats.staticcallCairo(FUNCTION_SELECTOR_CALCULATE_TWAP, data);
        require(returnData.length == 64, "Invalid return data length."); // 64 = 2 felts.

        assembly {
            // Load the values from the return data
            // returnData[0:32] is the length of the return data
            let price := mload(add(returnData, 0x20))
            let decimals := mload(add(returnData, 0x40))

            // Store the values in the response struct
            mstore(response, price)
            mstore(add(response, 0x20), decimals)
        }
        return response;
    }
}
