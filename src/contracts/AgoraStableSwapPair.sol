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
// ====================== AgoraStableSwapPair =========================
// ====================================================================

import { AgoraStableSwapPairConfiguration } from "./AgoraStableSwapPairConfiguration.sol";

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice The ```InitializeParams``` struct is used to initialize the AgoraStableSwapPair
/// @param token0 The address of token0
/// @param token0Decimals The number of decimals for token0
/// @param token1 The address of token1
/// @param token1Decimals The number of decimals for token1
/// @param minToken0PurchaseFee The minimum purchase fee for token0, 18 decimals precision, max value 1
/// @param maxToken0PurchaseFee The maximum purchase fee for token0, 18 decimals precision, max value 1
/// @param minToken1PurchaseFee The minimum purchase fee for token1, 18 decimals precision, max value 1
/// @param maxToken1PurchaseFee The maximum purchase fee for token1, 18 decimals precision, max value 1
/// @param token0PurchaseFee The purchase fee for token0, 18 decimals precision, max value 1
/// @param token1PurchaseFee The purchase fee for token1, 18 decimals precision, max value 1
/// @param initialAdminAddress The address of the initial admin
/// @param initialWhitelister The address of the initial whitelister
/// @param initialFeeSetter The address of the initial fee setter
/// @param initialTokenRemover The address of the initial token remover
/// @param initialPauser The address of the initial pauser
/// @param initialPriceSetter The address of the initial price setter
/// @param initialTokenReceiver The address of the initial token receiver
/// @param initialFeeReceiver The address of the initial fee receiver
/// @param minBasePrice The minimum base price for the pair, 18 decimals precision, min/max value determined by difference between decimals of token0 and token1
/// @param maxBasePrice The maximum base price for the pair, 18 decimals precision, min/max value determined by difference between decimals of token0 and token1
/// @param minAnnualizedInterestRate The minimum annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
/// @param maxAnnualizedInterestRate The maximum annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
/// @param basePrice The base price for the pair, 18 decimals precision, limited by token0 and token1 decimals
/// @param annualizedInterestRate The annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
struct InitializeParams {
    address token0;
    uint8 token0Decimals;
    address token1;
    uint8 token1Decimals;
    uint256 minToken0PurchaseFee;
    uint256 maxToken0PurchaseFee;
    uint256 minToken1PurchaseFee;
    uint256 maxToken1PurchaseFee;
    uint256 token0PurchaseFee;
    uint256 token1PurchaseFee;
    address initialAdminAddress;
    address initialWhitelister;
    address initialFeeSetter;
    address initialTokenRemover;
    address initialPauser;
    address initialPriceSetter;
    address initialTokenReceiver;
    address initialFeeReceiver;
    uint256 minBasePrice;
    uint256 maxBasePrice;
    int256 minAnnualizedInterestRate;
    int256 maxAnnualizedInterestRate;
    uint256 basePrice;
    int256 annualizedInterestRate;
}

/// @title AgoraStableSwapPair
/// @notice The AgoraStableSwapPair allows whitelisted users to swap between two tokens with a fixed price
/// @author Agora
contract AgoraStableSwapPair is AgoraStableSwapPairConfiguration {
    using SafeCast for uint256;

    //==============================================================================
    // Constructor & Initalization Functions
    //==============================================================================

    constructor() {
        _disableInitializers();
    }

    /// @notice The ```initialize``` function initializes the AgoraStableSwapPair contract
    /// @param _params The parameters for the initialization
    function initialize(InitializeParams memory _params) external initializer {
        // Check decimals match decimals of token0 and token1
        if (_params.token0Decimals != IERC20Metadata(_params.token0).decimals()) revert IncorrectDecimals();
        if (_params.token1Decimals != IERC20Metadata(_params.token1).decimals()) revert IncorrectDecimals();

        // Set the token0 and token1 and decimals
        _getPointerToStorage().swapStorage.token0 = _params.token0;
        _getPointerToStorage().configStorage.token0Decimals = _params.token0Decimals;
        _getPointerToStorage().swapStorage.token1 = _params.token1;
        _getPointerToStorage().configStorage.token1Decimals = _params.token1Decimals;

        // Initialize the access control and oracle
        _initializeAgoraStableSwapAccessControl({
            _initialAdminAddress: _params.initialAdminAddress,
            _initialWhitelister: _params.initialWhitelister,
            _initialFeeSetter: _params.initialFeeSetter,
            _initialTokenRemover: _params.initialTokenRemover,
            _initialPauser: _params.initialPauser,
            _initialPriceSetter: _params.initialPriceSetter
        });

        // assign roles to deployer for initialization
        _assignRole({ _role: ACCESS_CONTROL_ADMIN_ROLE, _newAddress: msg.sender, _addRole: true });
        _assignRole({ _role: PRICE_SETTER_ROLE, _newAddress: msg.sender, _addRole: true });
        _assignRole({ _role: FEE_SETTER_ROLE, _newAddress: msg.sender, _addRole: true });

        // Set the tokenReceiverAddress
        setTokenReceiver({ _tokenReceiver: _params.initialTokenReceiver });

        // Set the feeReceiver address
        setFeeReceiver({ _feeReceiver: _params.initialFeeReceiver });

        // Set the fee bounds
        setFeeBounds({
            _minToken0PurchaseFee: _params.minToken0PurchaseFee,
            _maxToken0PurchaseFee: _params.maxToken0PurchaseFee,
            _minToken1PurchaseFee: _params.minToken1PurchaseFee,
            _maxToken1PurchaseFee: _params.maxToken1PurchaseFee
        });

        // Set the token0to1Fee and token1to0Fee
        setTokenPurchaseFees({
            _token0PurchaseFee: _params.token0PurchaseFee,
            _token1PurchaseFee: _params.token1PurchaseFee
        });

        // Configure oracle price bounds
        setOraclePriceBounds({
            _minBasePrice: _params.minBasePrice,
            _maxBasePrice: _params.maxBasePrice,
            _minAnnualizedInterestRate: _params.minAnnualizedInterestRate,
            _maxAnnualizedInterestRate: _params.maxAnnualizedInterestRate
        });

        // Configure the oracle price
        configureOraclePrice({
            _basePrice: _params.basePrice,
            _annualizedInterestRate: _params.annualizedInterestRate
        });

        // Remove privileges from deployer
        _assignRole({ _role: ACCESS_CONTROL_ADMIN_ROLE, _newAddress: msg.sender, _addRole: false });
        _assignRole({ _role: PRICE_SETTER_ROLE, _newAddress: msg.sender, _addRole: false });
        _assignRole({ _role: FEE_SETTER_ROLE, _newAddress: msg.sender, _addRole: false });
    }

    //==============================================================================
    //  SwapStorage View Functions
    //==============================================================================

    /// @notice The ```isPaused``` function returns whether the pair is paused
    /// @return _isPaused Whether the pair is paused
    function isPaused() public view returns (bool) {
        return _getPointerToStorage().swapStorage.isPaused;
    }

    /// @notice The ```token0``` function returns the address of the token0 in the pair
    /// @return _token0 The address of the token0 in the pair
    function token0() public view returns (address) {
        return _getPointerToStorage().swapStorage.token0;
    }

    /// @notice The ```token1``` function returns the address of the token1 in the pair
    /// @return _token1 The address of the token1 in the pair
    function token1() public view returns (address) {
        return _getPointerToStorage().swapStorage.token1;
    }

    /// @notice The ```reserve0``` function returns the reserve of the token0 in the pair
    /// @return _reserve0 The reserve of the token0 in the pair
    function reserve0() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.reserve0;
    }

    /// @notice The ```reserve1``` function returns the reserve of the token1 in the pair
    /// @return _reserve1 The reserve of the token1 in the pair
    function reserve1() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.reserve1;
    }

    /// @notice The ```token0PurchaseFee``` function returns the purchase fee for the token0 in the pair
    /// @return _token0PurchaseFee The purchase fee for the token0 in the pair
    function token0PurchaseFee() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.token0PurchaseFee;
    }

    /// @notice The ```token1PurchaseFee``` function returns the purchase fee for the token1 in the pair
    /// @return _token1PurchaseFee The purchase fee for the token1 in the pair
    function token1PurchaseFee() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.token1PurchaseFee;
    }

    /// @notice The ```priceLastUpdated``` function returns the timestamp when the price was updated
    /// @return _priceLastUpdated The timestamp when the price was updated
    function priceLastUpdated() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.priceLastUpdated;
    }

    /// @notice The ```perSecondInterestRate``` function returns the per second interest rate
    /// @return _perSecondInterestRate The per second interest rate
    function perSecondInterestRate() public view returns (int256) {
        return _getPointerToStorage().swapStorage.perSecondInterestRate;
    }

    /// @notice The ```basePrice``` function returns the base price
    /// @return _basePrice The base price
    function basePrice() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.basePrice;
    }

    /// @notice The ```token0FeesAccumulated``` function returns the accumulated fees for token0
    /// @return _token0FeesAccumulated The accumulated fees for token0
    function token0FeesAccumulated() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.token0FeesAccumulated;
    }

    /// @notice The ```token1FeesAccumulated``` function returns the accumulated fees for token1
    /// @return _token1FeesAccumulated The accumulated fees for token1
    function token1FeesAccumulated() public view returns (uint256) {
        return _getPointerToStorage().swapStorage.token1FeesAccumulated;
    }

    //==============================================================================
    //  ConfigStorage View Functions
    //==============================================================================

    /// @notice The ```minToken0PurchaseFee``` function returns the minimum purchase fee for token0
    /// @return _minToken0PurchaseFee The minimum purchase fee for token0
    function minToken0PurchaseFee() public view returns (uint256) {
        return _getPointerToStorage().configStorage.minToken0PurchaseFee;
    }

    /// @notice The ```maxToken0PurchaseFee``` function returns the maximum purchase fee for token0
    /// @return _maxToken0PurchaseFee The maximum purchase fee for token0
    function maxToken0PurchaseFee() public view returns (uint256) {
        return _getPointerToStorage().configStorage.maxToken0PurchaseFee;
    }

    /// @notice The ```minToken1PurchaseFee``` function returns the minimum purchase fee for token1
    /// @return _minToken1PurchaseFee The minimum purchase fee for token1
    function minToken1PurchaseFee() public view returns (uint256) {
        return _getPointerToStorage().configStorage.minToken1PurchaseFee;
    }

    /// @notice The ```maxToken1PurchaseFee``` function returns the maximum purchase fee for token1
    /// @return _maxToken1PurchaseFee The maximum purchase fee for token1
    function maxToken1PurchaseFee() public view returns (uint256) {
        return _getPointerToStorage().configStorage.maxToken1PurchaseFee;
    }

    /// @notice The ```tokenReceiverAddress``` function returns the address of the token receiver
    /// @return _tokenReceiverAddress The address of the token receiver
    function tokenReceiverAddress() public view returns (address) {
        return _getPointerToStorage().configStorage.tokenReceiverAddress;
    }

    /// @notice The ```feeReceiverAddress``` function returns the address of the fee receiver
    /// @return _feeReceiverAddress The address of the fee receiver
    function feeReceiverAddress() public view returns (address) {
        return _getPointerToStorage().configStorage.feeReceiverAddress;
    }

    /// @notice The ```minBasePrice``` function returns the minimum base price
    /// @return _minBasePrice The minimum base price
    function minBasePrice() public view returns (uint256) {
        return _getPointerToStorage().configStorage.minBasePrice;
    }

    /// @notice The ```maxBasePrice``` function returns the maximum base price
    /// @return _maxBasePrice The maximum base price
    function maxBasePrice() public view returns (uint256) {
        return _getPointerToStorage().configStorage.maxBasePrice;
    }

    /// @notice The ```minAnnualizedInterestRate``` function returns the minimum annualized interest rate
    /// @return _minAnnualizedInterestRate The minimum annualized interest rate
    function minAnnualizedInterestRate() public view returns (int256) {
        return _getPointerToStorage().configStorage.minAnnualizedInterestRate;
    }

    /// @notice The ```maxAnnualizedInterestRate``` function returns the maximum annualized interest rate
    /// @return _maxAnnualizedInterestRate The maximum annualized interest rate
    function maxAnnualizedInterestRate() public view returns (int256) {
        return _getPointerToStorage().configStorage.maxAnnualizedInterestRate;
    }

    /// @notice The ```token0Decimals``` function returns the decimals of the token0 in the pair
    /// @return _token0Decimals The decimals of the token0 in the pair
    function token0Decimals() public view returns (uint8) {
        return _getPointerToStorage().configStorage.token0Decimals;
    }

    /// @notice The ```token1Decimals``` function returns the decimals of the token1 in the pair
    /// @return _token1Decimals The decimals of the token1 in the pair
    function token1Decimals() public view returns (uint8) {
        return _getPointerToStorage().configStorage.token1Decimals;
    }

    //==============================================================================
    // View Functions
    //==============================================================================

    /// @notice The ```getAmountsOut``` function calculates the amount of tokenOut returned from a given amount of tokenIn
    /// @param _amountIn The amount of input tokenIn
    /// @param _path The path of the tokens
    /// @return _amounts The amount of returned output tokenOut
    function getAmountsOut(uint256 _amountIn, address[] memory _path) public view returns (uint256[] memory _amounts) {
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _token0OverToken1Price = getPrice();

        // Checks: path length is 2 && path must contain token0 and token1 only
        requireValidPath({ _path: _path, _token0: _swapStorage.token0, _token1: _swapStorage.token1 });

        // Checks: amountIn is greater than 0
        if (_amountIn == 0) revert InsufficientInputAmount();

        // instantiate return variables
        _amounts = new uint256[](2);
        _amounts[0] = _amountIn;

        // path[1] represents our tokenOut
        if (_path[1] == _swapStorage.token0) {
            (_amounts[1], ) = getAmount0Out({
                _amount1In: _amountIn,
                _token0OverToken1Price: _token0OverToken1Price,
                _token0PurchaseFee: _swapStorage.token0PurchaseFee
            });
            if (_amounts[1] > _swapStorage.reserve0) revert InsufficientLiquidity();
        } else {
            (_amounts[1], ) = getAmount1Out({
                _amount0In: _amountIn,
                _token0OverToken1Price: _token0OverToken1Price,
                _token1PurchaseFee: _swapStorage.token1PurchaseFee
            });
            if (_amounts[1] > _swapStorage.reserve1) revert InsufficientLiquidity();
        }
    }

    /// @notice The ```getAmountsIn``` function calculates the amount of input tokensIn required for a given amount tokensOut
    /// @param _amountOut The amount of output tokenOut
    /// @param _path The path of the tokens
    /// @return _amounts The amount of required input tokenIn
    function getAmountsIn(uint256 _amountOut, address[] memory _path) public view returns (uint256[] memory _amounts) {
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _token0OverToken1Price = getPrice();

        // Checks: path length is 2 && path must contain token0 and token1 only
        requireValidPath({ _path: _path, _token0: _swapStorage.token0, _token1: _swapStorage.token1 });
        if (_path[1] == _swapStorage.token0 && _amountOut > _swapStorage.reserve0) revert InsufficientLiquidity();
        if (_path[1] == _swapStorage.token1 && _amountOut > _swapStorage.reserve1) revert InsufficientLiquidity();

        // Checks: amountOut is greater than 0
        if (_amountOut == 0) revert InsufficientOutputAmount();

        // instantiate return variables
        _amounts = new uint256[](2);
        // set the amountOut
        _amounts[1] = _amountOut;

        // path[0] represents our tokenIn
        if (_path[0] == _swapStorage.token0) {
            (_amounts[0], ) = getAmount0In({
                _amount1Out: _amountOut,
                _token0OverToken1Price: _token0OverToken1Price,
                _token1PurchaseFee: _swapStorage.token1PurchaseFee
            });
        } else {
            (_amounts[0], ) = getAmount1In({
                _amount0Out: _amountOut,
                _token0OverToken1Price: _token0OverToken1Price,
                _token0PurchaseFee: _swapStorage.token0PurchaseFee
            });
        }
    }

    /// @notice The ```getPriceNormalized``` function returns a price in a human-readable format adjusting for differences in precision
    /// @return _normalizedPrice The normalized price with 18 decimals of precision
    function getPriceNormalized() external view returns (uint256 _normalizedPrice) {
        ConfigStorage memory _configStorage = _getPointerToStorage().configStorage;
        return (getPrice() * 10 ** _configStorage.token1Decimals) / 10 ** _configStorage.token0Decimals;
    }

    /// @notice The ```Version``` struct is used to represent the version of the AgoraStableSwapPair
    /// @param major The major version number
    /// @param minor The minor version number
    /// @param patch The patch version number
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
    }

    /// @notice The ```version``` function returns the version of the AgoraStableSwapPair
    /// @return _version The version of the AgoraStableSwapPair
    function version() external pure returns (Version memory _version) {
        _version = Version({ major: 0, minor: 1, patch: 0 });
    }
}
