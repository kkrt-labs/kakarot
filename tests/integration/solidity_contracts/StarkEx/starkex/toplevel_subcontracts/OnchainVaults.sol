// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.6.12;

import "../components/VaultDepositWithdrawal.sol";
import "../components/VaultLocks.sol";
import "../../components/MainGovernance.sol";
import "../../components/TokenTransfers.sol";
import "../../interactions/TokenAssetData.sol";
import "../../interactions/TokenQuantization.sol";
import "../../interfaces/SubContractor.sol";

contract OnchainVaults is
    SubContractor,
    MainGovernance,
    VaultLocks,
    TokenAssetData,
    TokenTransfers,
    TokenQuantization,
    VaultDepositWithdrawal
{
    function initialize(bytes calldata) external override {
        revert("NOT_IMPLEMENTED");
    }

    function initializerSize() external view override returns (uint256) {
        return 0;
    }

    function isStrictVaultBalancePolicy() external view returns (bool) {
        return strictVaultBalancePolicy;
    }

    function validatedSelectors() external pure override returns (bytes4[] memory selectors) {
        uint256 len_ = 2;
        uint256 index_ = 0;

        selectors = new bytes4[](len_);
        selectors[index_++] = VaultDepositWithdrawal.withdrawErc1155FromVault.selector;
        selectors[index_++] = VaultDepositWithdrawal.withdrawFromVault.selector;
        require(index_ == len_, "INCORRECT_SELECTORS_ARRAY_LENGTH");
    }

    function identify() external pure override returns (string memory) {
        return "StarkWare_OnchainVaults_2022_2";
    }
}
