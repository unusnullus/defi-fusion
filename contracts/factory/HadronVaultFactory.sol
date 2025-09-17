// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {HadronVaultInitData} from "../vaults/HadronVault.sol";
import {HadronVault} from "../vaults/HadronVault.sol";

/// @title HadronVaultFactory
/// @notice Factory contract for creating and deploying new HadronVault instances
/// @dev This factory uses the standard deployment pattern; each call creates an independent HadronVault
contract HadronVaultFactory {
    /// @notice Emitted when a new HadronVault is created
    /// @param index The index of the HadronVault instance
    /// @param hadronVault The address of the newly created HadronVault
    /// @param assetName The name of the underlying asset
    /// @param assetSymbol The symbol of the underlying asset
    /// @param underlyingToken The address of the underlying token contract
    event HadronVaultCreated(
        uint256 index,
        address hadronVault,
        string assetName,
        string assetSymbol,
        address underlyingToken
    );

    /// @notice Creates a new HadronVault instance with the specified initialization parameters
    /// @param index_ The index of the HadronVault instance
    /// @param initData_ The initialization data containing vault configuration parameters
    /// @return hadronVault The address of the newly created HadronVault contract
    function create(uint256 index_, HadronVaultInitData memory initData_) external returns (address hadronVault) {
        hadronVault = address(new HadronVault(initData_));
        emit HadronVaultCreated(
            index_,
            hadronVault,
            initData_.assetName,
            initData_.assetSymbol,
            initData_.underlyingToken
        );
    }
}


