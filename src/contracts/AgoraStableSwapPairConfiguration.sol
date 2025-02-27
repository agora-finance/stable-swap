// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ================ AgoraStableSwapPairConfiguration ===================
// ====================================================================

import { AgoraStableSwapPairCore } from "./AgoraStableSwapPairCore.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title AgoraStableSwapPairConfiguration
/// @notice The AgoraStableSwapPairConfiguration is a contract that manages the privileged configuration setters for the AgoraStableSwapPair
/// @author Agora
abstract contract AgoraStableSwapPairConfiguration is AgoraStableSwapPairCore {
    using SafeCast for *;
    using SafeERC20 for IERC20;

    //==============================================================================
    // Privileged Configuration Functions
    //==============================================================================

    /// @notice The ```setTokenReceiver``` function sets the token receiver
    /// @dev Only the access control admin can set the token receiver
    /// @param _tokenReceiver The address of the token receiver
    function setTokenReceiver(address _tokenReceiver) public {
        // Checks: Only the access control admin can set the token receiver
        _requireSenderIsRole({ _role: ACCESS_CONTROL_ADMIN_ROLE });

        // Effects: Set the token receiver
        _getPointerToStorage().configStorage.tokenReceiverAddress = _tokenReceiver;

        // emit event
        emit SetTokenReceiver({ tokenReceiver: _tokenReceiver });
    }

    /// @notice The ```setFeeReceiver``` function sets the fee receiver
    /// @dev Only the access control admin can set the fee receiver
    /// @param _feeReceiver The address of the fee receiver
    function setFeeReceiver(address _feeReceiver) public {
        // Checks: Only the access control admin can set the fee receiver
        _requireSenderIsRole({ _role: ACCESS_CONTROL_ADMIN_ROLE });

        // Effects: Set the fee receiver
        _getPointerToStorage().configStorage.feeReceiverAddress = _feeReceiver;

        // emit event
        emit SetFeeReceiver({ feeReceiver: _feeReceiver });
    }

    /// @notice The ```setApprovedSwapper``` function sets the approved swappers
    /// @dev Only the whitelister can set the approved swappers
    /// @param _approvedSwappers The addresses of the approved swappers
    /// @param _setApproved The boolean value indicating whether the swappers are approved
    function setApprovedSwappers(address[] memory _approvedSwappers, bool _setApproved) public {
        // Checks: Only the whitelister can set the approved swapper
        _requireSenderIsRole({ _role: WHITELISTER_ROLE });

        for (uint256 _i = 0; _i < _approvedSwappers.length; _i++) {
            // Effects: Set the isApproved state
            _assignRole({ _role: APPROVED_SWAPPER, _newAddress: _approvedSwappers[_i], _addRole: _setApproved });

            // emit event
            emit SetApprovedSwapper({ approvedSwapper: _approvedSwappers[_i], isApproved: _setApproved });
        }
    }

    /// @notice The ```setFeeBounds``` function sets the fee bounds
    /// @dev Only the access control admin can set the fee bounds
    /// @param _minToken0PurchaseFee The minimum purchase fee for token0
    /// @param _maxToken0PurchaseFee The maximum purchase fee for token0
    /// @param _minToken1PurchaseFee The minimum purchase fee for token1
    /// @param _maxToken1PurchaseFee The maximum purchase fee for token1
    function setFeeBounds(
        uint256 _minToken0PurchaseFee,
        uint256 _maxToken0PurchaseFee,
        uint256 _minToken1PurchaseFee,
        uint256 _maxToken1PurchaseFee
    ) public {
        // Checks: Only the access control admin can set the fee bounds
        _requireSenderIsRole({ _role: ACCESS_CONTROL_ADMIN_ROLE });

        // Checks: Ensure the params are valid
        if (_minToken0PurchaseFee > _maxToken0PurchaseFee) revert MinToken0PurchaseFeeGreaterThanMax();
        if (_minToken1PurchaseFee > _maxToken1PurchaseFee) revert MinToken1PurchaseFeeGreaterThanMax();

        // Effects: Set the fee bounds
        _getPointerToStorage().configStorage.minToken0PurchaseFee = _minToken0PurchaseFee;
        _getPointerToStorage().configStorage.maxToken0PurchaseFee = _maxToken0PurchaseFee;
        _getPointerToStorage().configStorage.minToken1PurchaseFee = _minToken1PurchaseFee;
        _getPointerToStorage().configStorage.maxToken1PurchaseFee = _maxToken1PurchaseFee;

        // emit event
        emit SetFeeBounds({
            minToken0PurchaseFee: _minToken0PurchaseFee,
            maxToken0PurchaseFee: _maxToken0PurchaseFee,
            minToken1PurchaseFee: _minToken1PurchaseFee,
            maxToken1PurchaseFee: _maxToken1PurchaseFee
        });
    }

    /// @notice The ```setTokenPurchaseFees``` function sets the token purchase fees
    /// @dev Only the fee setter can set the fee
    /// @param _token0PurchaseFee The purchase fee for token0
    /// @param _token1PurchaseFee The purchase fee for token1
    function setTokenPurchaseFees(uint256 _token0PurchaseFee, uint256 _token1PurchaseFee) public {
        // Checks: Only the fee setter can set the fee
        _requireSenderIsRole({ _role: FEE_SETTER_ROLE });

        // Checks: Ensure the params are valid and within the bounds
        if (
            _token0PurchaseFee < _getPointerToStorage().configStorage.minToken0PurchaseFee ||
            _token0PurchaseFee > _getPointerToStorage().configStorage.maxToken0PurchaseFee
        ) revert InvalidToken0PurchaseFee();
        if (
            _token1PurchaseFee < _getPointerToStorage().configStorage.minToken1PurchaseFee ||
            _token1PurchaseFee > _getPointerToStorage().configStorage.maxToken1PurchaseFee
        ) revert InvalidToken1PurchaseFee();

        // Effects: Set the token purchase fees
        _getPointerToStorage().swapStorage.token0PurchaseFee = _token0PurchaseFee.toUint64();
        _getPointerToStorage().swapStorage.token1PurchaseFee = _token1PurchaseFee.toUint64();

        // emit event
        emit SetTokenPurchaseFees({ token0PurchaseFee: _token0PurchaseFee, token1PurchaseFee: _token1PurchaseFee });
    }

    /// @notice The ```removeTokens``` function removes tokens from the pair
    /// @dev Only the token remover can remove tokens
    /// @param _tokenAddress The address of the token
    /// @param _amount The amount of tokens to remove
    function removeTokens(address _tokenAddress, uint256 _amount) external {
        // Checks: Only the token remover can remove tokens
        _requireSenderIsRole({ _role: TOKEN_REMOVER_ROLE });

        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        ConfigStorage memory _configStorage = _getPointerToStorage().configStorage;

        uint256 _token0Balance = IERC20(_swapStorage.token0).balanceOf(address(this));
        uint256 _token1Balance = IERC20(_swapStorage.token1).balanceOf(address(this));

        // Checks: sufficient tokens available (we check the actual balance here instead of reserves)
        if (_tokenAddress == _swapStorage.token0 && _amount > _token0Balance - _swapStorage.token0FeesAccumulated) {
            revert InsufficientTokens();
        }
        if (_tokenAddress == _swapStorage.token1 && _amount > _token1Balance - _swapStorage.token1FeesAccumulated) {
            revert InsufficientTokens();
        }

        // Interactions: transfer tokens from the pair to the token receiver
        IERC20(_tokenAddress).safeTransfer({ to: _configStorage.tokenReceiverAddress, value: _amount });

        // Update reserves + fees accumulated
        _sync({
            _token0Balance: IERC20(_swapStorage.token0).balanceOf(address(this)),
            _token1Balance: IERC20(_swapStorage.token1).balanceOf(address(this)),
            _token0FeesAccumulated: _swapStorage.token0FeesAccumulated,
            _token1FeesAccumulated: _swapStorage.token1FeesAccumulated
        });

        // emit event
        emit RemoveTokens({ tokenAddress: _tokenAddress, amount: _amount });
    }

    /// @notice The ```collectFees``` function removes accumulated fees from the pair
    /// @dev Only the token remover can collect fees
    /// @param _tokenAddress The address of the token
    /// @param _amount The amount of tokens to remove
    function collectFees(address _tokenAddress, uint256 _amount) external {
        // Checks: Only the tokenRemover can remove tokens
        _requireSenderIsRole({ _role: TOKEN_REMOVER_ROLE });

        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        ConfigStorage memory _configStorage = _getPointerToStorage().configStorage;

        // Checks: sufficient fees accumulated
        if (_tokenAddress == _swapStorage.token0 && _amount > _swapStorage.token0FeesAccumulated) {
            revert InsufficientTokens();
        }
        if (_tokenAddress == _swapStorage.token1 && _amount > _swapStorage.token1FeesAccumulated) {
            revert InsufficientTokens();
        }

        // Interactions: transfer fees from the pair to the fee receiver
        IERC20(_tokenAddress).safeTransfer({ to: _configStorage.feeReceiverAddress, value: _amount });

        // Calculate fees accumulated based on which token was transferred out
        if (_tokenAddress == _swapStorage.token0) {
            _swapStorage.token0FeesAccumulated -= _amount.toUint128();
        } else if (_tokenAddress == _swapStorage.token1) {
            _swapStorage.token1FeesAccumulated -= _amount.toUint128();
        } else {
            // If trying to remove a token not part of the pair, use the removeTokens function
            revert InvalidTokenAddress();
        }

        // Update reserves + fees accumulated
        _sync({
            _token0Balance: IERC20(_swapStorage.token0).balanceOf(address(this)),
            _token1Balance: IERC20(_swapStorage.token1).balanceOf(address(this)),
            _token0FeesAccumulated: _swapStorage.token0FeesAccumulated,
            _token1FeesAccumulated: _swapStorage.token1FeesAccumulated
        });

        // emit event
        emit RemoveTokens({ tokenAddress: _tokenAddress, amount: _amount });
    }

    /// @notice The ```setPaused``` function sets the paused state of the pair
    /// @dev Only the pauser can pause the pair
    /// @param _setPaused The boolean value indicating whether the pair is paused
    function setPaused(bool _setPaused) public {
        // Checks: Only the pauser can pause the pair
        _requireSenderIsRole({ _role: PAUSER_ROLE });

        // Effects: Set the isPaused state
        _getPointerToStorage().swapStorage.isPaused = _setPaused;

        // emit event
        emit SetPaused({ isPaused: _setPaused });
    }

    /// @notice The ```setOraclePriceBounds``` function sets the price bounds for the pair
    /// @dev Only the access control admin can set the price bounds
    /// @param _minBasePrice The minimum allowed initial base price
    /// @param _maxBasePrice The maximum allowed initial base price
    /// @param _minAnnualizedInterestRate The minimum allowed annualized interest rate
    /// @param _maxAnnualizedInterestRate The maximum allowed annualized interest rate
    function setOraclePriceBounds(
        uint256 _minBasePrice,
        uint256 _maxBasePrice,
        int256 _minAnnualizedInterestRate,
        int256 _maxAnnualizedInterestRate
    ) public {
        // Checks: Only the access control admin can set the price bounds
        _requireSenderIsRole({ _role: ACCESS_CONTROL_ADMIN_ROLE });
        // Checks: parameters are valid
        if (_minBasePrice > _maxBasePrice) revert MinBasePriceGreaterThanMaxBasePrice();
        if (_minAnnualizedInterestRate > _maxAnnualizedInterestRate) revert MinAnnualizedInterestRateGreaterThanMax();

        // Effects: Set the price and annualized interest bounds
        _getPointerToStorage().configStorage.minBasePrice = _minBasePrice;
        _getPointerToStorage().configStorage.maxBasePrice = _maxBasePrice;
        _getPointerToStorage().configStorage.minAnnualizedInterestRate = _minAnnualizedInterestRate;
        _getPointerToStorage().configStorage.maxAnnualizedInterestRate = _maxAnnualizedInterestRate;

        // emit event
        emit SetOraclePriceBounds({
            minBasePrice: _minBasePrice,
            maxBasePrice: _maxBasePrice,
            minAnnualizedInterestRate: _minAnnualizedInterestRate,
            maxAnnualizedInterestRate: _maxAnnualizedInterestRate
        });
    }

    /// @notice The ```configureOraclePrice``` function configures the price of the pair
    /// @dev Only the price setter can configure the price
    /// @param _basePrice The base price of the pair
    /// @param _annualizedInterestRate The annualized interest rate
    function configureOraclePrice(uint256 _basePrice, int256 _annualizedInterestRate) public {
        // Checks: Only the price setter can configure the price
        _requireSenderIsRole({ _role: PRICE_SETTER_ROLE });

        ConfigStorage memory _configStorage = _getPointerToStorage().configStorage;

        // Checks: price is within bounds
        if (_basePrice < _configStorage.minBasePrice || _basePrice > _configStorage.maxBasePrice) {
            revert BasePriceOutOfBounds();
        }
        if (
            _annualizedInterestRate < _configStorage.minAnnualizedInterestRate ||
            _annualizedInterestRate > _configStorage.maxAnnualizedInterestRate
        ) revert AnnualizedInterestRateOutOfBounds();

        // Effects: Set the time of the last price update
        _getPointerToStorage().swapStorage.priceLastUpdated = (block.timestamp).toUint40();
        // Effects: Convert yearly APR to per second APR
        _getPointerToStorage().swapStorage.perSecondInterestRate = (_annualizedInterestRate / 365 days).toInt72();
        // Effects: Set the price of the asset
        _getPointerToStorage().swapStorage.basePrice = (_basePrice).toUint64();

        // emit event
        emit ConfigureOraclePrice(_basePrice, _annualizedInterestRate);
    }
}
