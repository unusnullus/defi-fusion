// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IHadronVaultBase as IPlasmaVaultBase} from "../interfaces/IHadronVaultBase.sol";
import {Errors} from "../libraries/errors/Errors.sol";
import {HadronVaultGovernance as PlasmaVaultGovernance} from "./HadronVaultGovernance.sol";
import {ERC20VotesUpgradeable} from "./ERC20VotesUpgradeable.sol";
import {HadronVaultLib as PlasmaVaultLib} from "../libraries/HadronVaultLib.sol";
import {HadronVaultStorageLib as PlasmaVaultStorageLib} from "../libraries/HadronVaultStorageLib.sol";
import {ContextClient} from "../managers/context/ContextClient.sol";
import {PreHooksHandler} from "../handlers/pre_hooks/PreHooksHandler.sol";
/**
 * @title HadronVaultBase - Core Extension for Hadron Vault Token Functionality
 * @notice Stateless extension providing ERC20 Votes and Permit capabilities for HadronVault
 * @dev Designed to be used exclusively through delegatecall from HadronVault
 */
contract HadronVaultBase is
    IPlasmaVaultBase,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    PlasmaVaultGovernance,
    ContextClient,
    PreHooksHandler
{
    error ERC20ExceededCap(uint256 increasedSupply, uint256 cap);
    error ERC20InvalidCap(uint256 cap);

    function init(
        string memory assetName_,
        address accessManager_,
        uint256 totalSupplyCap_
    ) external override initializer {
        if (accessManager_ == address(0)) {
            revert Errors.WrongAddress();
        }

        super.__ERC20Votes_init();
        super.__ERC20Permit_init(assetName_);
        super.__AccessManaged_init(accessManager_);
        __init(totalSupplyCap_);
    }

    function __init(uint256 cap_) internal onlyInitializing {
        PlasmaVaultStorageLib.ERC20CappedStorage storage $ = PlasmaVaultStorageLib.getERC20CappedStorage();
        if (cap_ == 0) {
            revert ERC20InvalidCap(0);
        }
        $.cap = cap_;
    }

    function cap() public view virtual returns (uint256) {
        return PlasmaVaultStorageLib.getERC20CappedStorage().cap;
    }

    function transferRequestSharesFee(address from_, address to_, uint256 amount_) external override restricted {
        _transfer(from_, to_, amount_);
    }

    function updateInternal(address from_, address to_, uint256 value_) external override {
        _update(from_, to_, value_);
    }

    function nonces(address owner_) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner_);
    }

    function _update(address from_, address to_, uint256 value_) internal virtual override {
        super._update(from_, to_, value_);

        if (PlasmaVaultLib.isTotalSupplyCapValidationEnabled()) {
            if (from_ == address(0)) {
                uint256 maxSupply = cap();
                uint256 supply = totalSupply();
                if (supply > maxSupply) {
                    revert ERC20ExceededCap(supply, maxSupply);
                }
            }
        }

        _transferVotingUnits(from_, to_, value_);
    }

    function _msgSender() internal view override returns (address) {
        return _getSenderFromContext();
    }

    function _checkCanCall(address caller_, bytes calldata data_) internal override {
        super._checkCanCall(caller_, data_);
        _runPreHook(bytes4(data_[0:4]));
    }
}
