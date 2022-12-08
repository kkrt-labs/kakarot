// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../components/Escapes.sol";
import "../interactions/StarkExForcedActionState.sol";
import "../interactions/UpdateState.sol";
import "../../components/Freezable.sol";
import "../../components/MainGovernance.sol";
import "../../components/StarkExOperator.sol";
import "../../interactions/AcceptModifications.sol";
import "../../interactions/StateRoot.sol";
import "../../interactions/TokenQuantization.sol";
import "../../interfaces/SubContractor.sol";

contract StarkExState is
    MainGovernance,
    SubContractor,
    StarkExOperator,
    Freezable,
    AcceptModifications,
    TokenQuantization,
    StarkExForcedActionState,
    StateRoot,
    Escapes,
    UpdateState
{
    // InitializationArgStruct contains 2 * address + 8 * uint256 + 1 * bool = 352 bytes.
    uint256 constant INITIALIZER_SIZE = 11 * 32;

    struct InitializationArgStruct {
        uint256 globalConfigCode;
        address escapeVerifierAddress;
        uint256 sequenceNumber;
        uint256 validiumVaultRoot;
        uint256 rollupVaultRoot;
        uint256 orderRoot;
        uint256 validiumTreeHeight;
        uint256 rollupTreeHeight;
        uint256 orderTreeHeight;
        bool strictVaultBalancePolicy;
        address orderRegistryAddress;
    }

    /*
      Initialization flow:
      1. Extract initialization parameters from data.
      2. Call internalInitializer with those parameters.
    */
    function initialize(bytes calldata data) external virtual override {
        // This initializer sets roots etc. It must not be applied twice.
        // I.e. it can run only when the state is still empty.
        string memory ALREADY_INITIALIZED_MSG = "STATE_ALREADY_INITIALIZED";
        require(validiumVaultRoot == 0, ALREADY_INITIALIZED_MSG);
        require(validiumTreeHeight == 0, ALREADY_INITIALIZED_MSG);
        require(rollupVaultRoot == 0, ALREADY_INITIALIZED_MSG);
        require(rollupTreeHeight == 0, ALREADY_INITIALIZED_MSG);
        require(orderRoot == 0, ALREADY_INITIALIZED_MSG);
        require(orderTreeHeight == 0, ALREADY_INITIALIZED_MSG);

        require(data.length == INITIALIZER_SIZE, "INCORRECT_INIT_DATA_SIZE_352");

        // Copies initializer values into initValues.
        InitializationArgStruct memory initValues;
        bytes memory _data = data;
        assembly {
            initValues := add(32, _data)
        }
        require(initValues.globalConfigCode < K_MODULUS, "GLOBAL_CONFIG_CODE >= PRIME");
        require(initValues.validiumTreeHeight < ROLLUP_VAULTS_BIT, "INVALID_VALIDIUM_HEIGHT");
        require(initValues.rollupTreeHeight < ROLLUP_VAULTS_BIT, "INVALID_ROLLUP_HEIGHT");

        initGovernance();
        StarkExOperator.initialize();
        StateRoot.initialize(
            initValues.sequenceNumber,
            initValues.validiumVaultRoot,
            initValues.rollupVaultRoot,
            initValues.orderRoot,
            initValues.validiumTreeHeight,
            initValues.rollupTreeHeight,
            initValues.orderTreeHeight
        );
        Escapes.initialize(initValues.escapeVerifierAddress);
        globalConfigCode = initValues.globalConfigCode;
        strictVaultBalancePolicy = initValues.strictVaultBalancePolicy;
        orderRegistryAddress = initValues.orderRegistryAddress;
    }

    /*
      The call to initializerSize is done from MainDispatcherBase using delegatecall,
      thus the existing state is already accessible.
    */
    function initializerSize() external view virtual override returns (uint256) {
        return INITIALIZER_SIZE;
    }

    function validatedSelectors() external pure override returns (bytes4[] memory selectors) {
        uint256 len_ = 1;
        uint256 index_ = 0;

        selectors = new bytes4[](len_);
        selectors[index_++] = Escapes.escape.selector;
        require(index_ == len_, "INCORRECT_SELECTORS_ARRAY_LENGTH");
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_StarkExState_2022_5";
    }
}
