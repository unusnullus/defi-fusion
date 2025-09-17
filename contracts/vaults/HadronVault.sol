// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Errors} from "../libraries/errors/Errors.sol";
import {IPlasmaVault, FuseAction} from "../interfaces/IPlasmaVault.sol";
import {IFuseCommon} from "../gluons/IFuseCommon.sol";
import {IPlasmaVaultBase} from "../interfaces/IPlasmaVaultBase.sol";
import {AccessManagedUpgradeable} from "../managers/access/AccessManagedUpgradeable.sol";
import {CallbackHandlerLib} from "../libraries/CallbackHandlerLib.sol";
import {FusesLib} from "../libraries/FusesLib.sol";
import {HadronVaultLib as PlasmaVaultLib} from "../libraries/HadronVaultLib.sol";
import {UniversalReader} from "../universal_reader/UniversalReader.sol";
import {PreHooksHandler} from "../handlers/pre_hooks/PreHooksHandler.sol";

/// @title HadronVault Initialization Data Structure
struct HadronVaultInitData {
    string assetName;
    string assetSymbol;
    address underlyingToken;
    address accessManager;
    address plasmaVaultBase;
}

/// @title HadronVault - minimal, protocol-agnostic ERC4626 vault with fuse execution
contract HadronVault is
    ERC20Upgradeable,
    ERC4626Upgradeable,
    ReentrancyGuardUpgradeable,
    AccessManagedUpgradeable,
    UniversalReader,
    IPlasmaVault,
    PreHooksHandler
{
    using Address for address;
    using Math for uint256;

    error NoSharesToRedeem();
    error NoSharesToMint();
    error NoAssetsToWithdraw();
    error NoAssetsToDeposit();
    error NoSharesToDeposit();
    error UnsupportedFuse();
    error UnsupportedMethod();
    error PermitFailed();

    address public immutable PLASMA_VAULT_BASE;
    uint256 private immutable _SHARE_SCALE_MULTIPLIER;

    constructor(HadronVaultInitData memory initData_) ERC20Upgradeable() ERC4626Upgradeable() initializer {
        super.__ERC20_init(initData_.assetName, initData_.assetSymbol);
        super.__ERC4626_init(IERC20(initData_.underlyingToken));

        _SHARE_SCALE_MULTIPLIER = 10 ** _decimalsOffset();

        PLASMA_VAULT_BASE = initData_.plasmaVaultBase;

        PLASMA_VAULT_BASE.functionDelegateCall(
            abi.encodeWithSelector(
                IPlasmaVaultBase.init.selector,
                initData_.assetName,
                initData_.accessManager,
                type(uint256).max
            )
        );
    }

    fallback(bytes calldata) external returns (bytes memory) {
        if (PlasmaVaultLib.isExecutionStarted()) {
            CallbackHandlerLib.handleCallback();
            return "";
        } else {
            return PLASMA_VAULT_BASE.functionDelegateCall(msg.data);
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function execute(FuseAction[] calldata calls_) external override nonReentrant restricted {
        uint256 callsCount = calls_.length;
        uint256[] memory markets = new uint256[](callsCount);
        uint256 marketIndex;
        uint256 fuseMarketId;

        PlasmaVaultLib.executeStarted();

        for (uint256 i; i < callsCount; ++i) {
            if (!FusesLib.isFuseSupported(calls_[i].fuse)) {
                revert UnsupportedFuse();
            }

            fuseMarketId = IFuseCommon(calls_[i].fuse).MARKET_ID();

            if (_checkIfExistsMarket(markets, fuseMarketId) == false) {
                markets[marketIndex] = fuseMarketId;
                marketIndex++;
            }

            calls_[i].fuse.functionDelegateCall(calls_[i].data);
        }

        PlasmaVaultLib.executeFinished();

        _updateMarketsBalances(markets);
    }

    function updateMarketsBalances(uint256[] calldata) external restricted returns (uint256) {
        return totalAssets();
    }

    function decimals() public view virtual override(ERC20Upgradeable, ERC4626Upgradeable) returns (uint8) {
        return super.decimals();
    }

    function transfer(
        address to_,
        uint256 value_
    ) public virtual override(IERC20, ERC20Upgradeable) restricted returns (bool) {
        return super.transfer(to_, value_);
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 value_
    ) public virtual override(IERC20, ERC20Upgradeable) restricted returns (bool) {
        return super.transferFrom(from_, to_, value_);
    }

    function deposit(uint256 assets_, address receiver_) public override nonReentrant restricted returns (uint256) {
        return _deposit(assets_, receiver_);
    }

    function depositWithPermit(
        uint256 assets_,
        address receiver_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external override nonReentrant restricted returns (uint256) {
        try IERC20Permit(asset()).permit(_msgSender(), address(this), assets_, deadline_, v_, r_, s_) {
        } catch {
            if (IERC20(asset()).allowance(_msgSender(), address(this)) < assets_) {
                revert PermitFailed();
            }
        }
        return _deposit(assets_, receiver_);
    }

    function mint(uint256 shares_, address receiver_) public override nonReentrant restricted returns (uint256) {
        if (shares_ == 0) {
            revert NoSharesToMint();
        }
        if (receiver_ == address(0)) {
            revert Errors.WrongAddress();
        }
        return super.mint(shares_, receiver_);
    }

    function withdraw(
        uint256 assets_,
        address receiver_,
        address owner_
    ) public override nonReentrant restricted returns (uint256 withdrawnShares) {
        if (assets_ == 0) {
            revert NoAssetsToWithdraw();
        }
        if (receiver_ == address(0) || owner_ == address(0)) {
            revert Errors.WrongAddress();
        }
        uint256 maxAssets = maxWithdraw(owner_);
        if (assets_ > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner_, assets_, maxAssets);
        }
        uint256 shares = convertToShares(assets_);
        withdrawnShares = shares;
        super._withdraw(_msgSender(), receiver_, owner_, assets_, withdrawnShares);
    }

    function previewRedeem(uint256 shares_) public view override returns (uint256) {
        return super.previewRedeem(shares_);
    }

    function previewWithdraw(uint256 assets_) public view override returns (uint256) {
        return super.previewWithdraw(assets_);
    }

    function redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    ) public override nonReentrant restricted returns (uint256 withdrawnAssets) {
        uint256 maxShares = maxRedeem(owner_);
        if (shares_ > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner_, shares_, maxShares);
        }
        withdrawnAssets = _redeem(shares_, receiver_, owner_);
    }

    function redeemFromRequest(
        uint256 shares_,
        address receiver_,
        address owner_
    ) external override restricted returns (uint256) {
        return redeem(shares_, receiver_, owner_);
    }

    function maxDeposit(address) public view virtual override returns (uint256) {
        uint256 totalSupplyCap = PlasmaVaultLib.getTotalSupplyCap();
        uint256 totalSupply = totalSupply();
        if (totalSupply >= totalSupplyCap) {
            return 0;
        }
        uint256 exchangeRate = convertToAssets(10 ** uint256(decimals()));
        if (type(uint256).max / exchangeRate < totalSupplyCap - totalSupply) {
            return type(uint256).max;
        }
        return convertToAssets(totalSupplyCap - totalSupply);
    }

    function maxMint(address) public view virtual override returns (uint256) {
        uint256 totalSupplyCap = PlasmaVaultLib.getTotalSupplyCap();
        uint256 totalSupply = totalSupply();
        if (totalSupply >= totalSupplyCap) {
            return 0;
        }
        return totalSupplyCap - totalSupply;
    }

    function claimRewards(FuseAction[] calldata calls_) external override nonReentrant restricted {
        uint256 callsCount = calls_.length;
        for (uint256 i; i < callsCount; ++i) {
            calls_[i].fuse.functionDelegateCall(calls_[i].data);
        }
    }

    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function totalAssetsInMarket(uint256) public view virtual returns (uint256) {
        return 0;
    }

    function getUnrealizedManagementFee() public view returns (uint256) {
        return 0;
    }

    function updateInternal(address, address, uint256) public {
        revert UnsupportedMethod();
    }

    function executeInternal(FuseAction[] calldata calls_) external {
        if (address(this) != msg.sender) {
            revert Errors.WrongCaller(msg.sender);
        }
        uint256 callsCount = calls_.length;
        uint256[] memory markets = new uint256[](callsCount);
        uint256 marketIndex;
        uint256 fuseMarketId;

        for (uint256 i; i < callsCount; ++i) {
            if (!FusesLib.isFuseSupported(calls_[i].fuse)) {
                revert UnsupportedFuse();
            }
            fuseMarketId = IFuseCommon(calls_[i].fuse).MARKET_ID();
            if (_checkIfExistsMarket(markets, fuseMarketId) == false) {
                markets[marketIndex] = fuseMarketId;
                marketIndex++;
            }
            calls_[i].fuse.functionDelegateCall(calls_[i].data);
        }
        _updateMarketsBalances(markets);
    }

    function _redeem(
        uint256 shares_,
        address receiver_,
        address owner_
    ) internal returns (uint256 withdrawnAssets) {
        if (shares_ == 0) {
            revert NoSharesToRedeem();
        }
        if (receiver_ == address(0) || owner_ == address(0)) {
            revert Errors.WrongAddress();
        }
        withdrawnAssets = convertToAssets(shares_);
        _withdraw(_msgSender(), receiver_, owner_, withdrawnAssets, shares_);
    }

    function _deposit(uint256 assets_, address receiver_) internal returns (uint256) {
        if (assets_ == 0) {
            revert NoAssetsToDeposit();
        }
        if (receiver_ == address(0)) {
            revert Errors.WrongAddress();
        }
        uint256 shares = super.deposit(assets_, receiver_);
        if (shares == 0) {
            revert NoSharesToDeposit();
        }
        return shares;
    }

    function _withdrawFromMarkets(uint256, uint256) internal {}

    function _updateMarketsBalances(uint256[] memory) internal {}

    function _checkIfExistsMarket(uint256[] memory markets_, uint256 marketId_) internal pure returns (bool exists) {
        for (uint256 i; i < markets_.length; ++i) {
            if (markets_[i] == 0) {
                break;
            }
            if (markets_[i] == marketId_) {
                exists = true;
                break;
            }
        }
    }

    function _getGrossTotalAssets() internal view returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function _update(address from_, address to_, uint256 value_) internal virtual override {
        PLASMA_VAULT_BASE.functionDelegateCall(
            abi.encodeWithSelector(IPlasmaVaultBase.updateInternal.selector, from_, to_, value_)
        );
    }

    function _decimalsOffset() internal view virtual override returns (uint8) {
        return PlasmaVaultLib.DECIMALS_OFFSET;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets * _SHARE_SCALE_MULTIPLIER : assets.mulDiv(supply + _SHARE_SCALE_MULTIPLIER, totalAssets() + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares.mulDiv(1, _SHARE_SCALE_MULTIPLIER, rounding) : shares.mulDiv(totalAssets() + 1, supply + _SHARE_SCALE_MULTIPLIER, rounding);
    }
}


