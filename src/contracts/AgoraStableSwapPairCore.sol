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
// ==================== AgoraStableSwapPairCore =======================
// ====================================================================
import { AgoraStableSwapAccessControl } from "./AgoraStableSwapAccessControl.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IUniswapV2Callee } from "./interfaces/IUniswapV2Callee.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AgoraStableSwapPairCore
/// @notice The AgoraStableSwapPairCore is a contract that manages the core logic for the AgoraStableSwapPair
/// @author Agora
abstract contract AgoraStableSwapPairCore is AgoraStableSwapAccessControl, Initializable, ReentrancyGuardTransient {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    //==============================================================================
    // Storage Structs
    //==============================================================================

    /// @notice The ```ConfigStorage``` struct is used to store the configuration of the AgoraStableSwapPair
    /// @param minToken0PurchaseFee The minimum purchase fee for token0, 18 decimals precision, max value 1
    /// @param maxToken0PurchaseFee The maximum purchase fee for token0, 18 decimals precision, max value 1
    /// @param minToken1PurchaseFee The minimum purchase fee for token1, 18 decimals precision, max value 1
    /// @param maxToken1PurchaseFee The maximum purchase fee for token1, 18 decimals precision, max value 1
    /// @param tokenReceiverAddress The address of the token receiver
    /// @param feeReceiverAddress The address of the fee receiver
    /// @param minBasePrice The minimum base price for the pair, 18 decimals precision, min/max value determined by difference between decimals of token0 and token1
    /// @param maxBasePrice The maximum base price for the pair, 18 decimals precision, min/max value determined by difference between decimals of token0 and token1
    /// @param minAnnualizedInterestRate The minimum annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
    /// @param maxAnnualizedInterestRate The maximum annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
    /// @param token0Decimals The number of decimals for token0
    /// @param token1Decimals The number of decimals for token1
    struct ConfigStorage {
        uint256 minToken0PurchaseFee; // 18 decimals precision, max value 1
        uint256 maxToken0PurchaseFee; // 18 decimals precision, max value 1
        uint256 minToken1PurchaseFee; // 18 decimals precision, max value 1
        uint256 maxToken1PurchaseFee; // 18 decimals precision, max value 1
        address tokenReceiverAddress;
        address feeReceiverAddress;
        uint256 minBasePrice; // 18 decimals precision, max value determined by difference between decimals of token0 and token1
        uint256 maxBasePrice; // 18 decimals precision, max value determined by difference between decimals of token0 and token1
        int256 minAnnualizedInterestRate; // 18 decimals precision, given as number i.e. 1e16 = 1%
        int256 maxAnnualizedInterestRate; // 18 decimals precision, given as number i.e. 1e16 = 1%
        uint8 token0Decimals;
        uint8 token1Decimals;
    }

    /// @notice The ```SwapStorage``` struct is used to store the state of the AgoraStableSwapPair
    /// @param isPaused The boolean value indicating whether the pair is paused
    /// @param token0 The address of token0
    /// @param token1 The address of token1
    /// @param reserve0 The reserve of token0, given as raw value
    /// @param reserve1 The reserve of token1, given as raw value
    /// @param token0PurchaseFee The purchase fee for token0, 18 decimals precision, max value 1
    /// @param token1PurchaseFee The purchase fee for token1, 18 decimals precision, max value 1
    /// @param priceLastUpdated The last block timestamp when the price was updated
    /// @param perSecondInterestRate The per second interest rate for the pair, 18 decimals precision, given as whole number with 18 decimals of precision i.e. 1e16 = 1%
    /// @param basePrice The base price for the pair, 18 decimals precision, limited by token0 and token1 decimals
    /// @param token0FeesAccumulated The accumulated fees for token0, given as raw value
    /// @param token1FeesAccumulated The accumulated fees for token1, given as raw value
    struct SwapStorage {
        bool isPaused;
        address token0;
        address token1;
        uint112 reserve0;
        uint112 reserve1;
        uint64 token0PurchaseFee; // 18 decimals precision, max value 1
        uint64 token1PurchaseFee; // 18 decimals precision, max value 1
        uint40 priceLastUpdated;
        int72 perSecondInterestRate; // 18 decimals of precision, given as whole number i.e. 1e16 = 1%
        uint256 basePrice; // 18 decimals of precision, limited by token0 and token1 decimals
        uint128 token0FeesAccumulated;
        uint128 token1FeesAccumulated;
    }

    /// @notice The ```AgoraStableSwapStorage``` struct is used to store the state of the AgoraStableSwapPair contract
    /// @param swapStorage The swap storage struct, values used during call to swap()
    /// @param configStorage The config storage struct, values used outside of swap()
    struct AgoraStableSwapStorage {
        SwapStorage swapStorage;
        ConfigStorage configStorage;
    }

    //==============================================================================
    // Erc 7201: UnstructuredNamespace Storage Functions
    //==============================================================================

    /// @notice The ```AGORA_STABLE_SWAP_STORAGE_SLOT``` is the storage slot for the AgoraStableSwapStorage struct
    /// @dev keccak256(abi.encode(uint256(keccak256("AgoraStableSwapPairStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant AGORA_STABLE_SWAP_STORAGE_SLOT =
        0x7bec511bd7f6687e2731c8fe683a8e6468bf371b3ebd503eee87dd5465b4a500;

    /// @notice The ```_getPointerToAgoraStableSwapStorage``` function returns a pointer to the AgoraStableSwapStorage struct
    /// @return $ A pointer to the AgoraStableSwapStorage struct
    function _getPointerToStorage() internal pure returns (AgoraStableSwapStorage storage $) {
        /// @solidity memory-safe-assembly
        assembly {
            $.slot := AGORA_STABLE_SWAP_STORAGE_SLOT
        }
    }

    /// @notice The ```PRICE_PRECISION``` constant is the precision for the price, 18 decimals precision
    uint256 public constant PRICE_PRECISION = 1e18;
    /// @notice The ```FEE_PRECISION``` constant is the precision for the fees, 18 decimals precision
    uint256 public constant FEE_PRECISION = 1e18;

    //==============================================================================
    // Pure Helper Functions
    //==============================================================================

    /// @notice The ```requireValidPath``` function checks that the path is valid
    /// @param _path The path to check
    /// @param _token0 The address of the first token in the pair
    /// @param _token1 The address of the second token in the pair
    function requireValidPath(address[] memory _path, address _token0, address _token1) public pure {
        // Checks: path length is 2
        if (_path.length != 2) revert InvalidPathLength();

        if (!(_path[0] == _token0 && _path[1] == _token1) && !(_path[0] == _token1 && _path[1] == _token0)) {
            revert InvalidPath();
        }
    }

    /// @notice The ```getAmount0In``` function calculates the amount of input token0In required for a given amount token1Out
    /// @param _amount1Out The amount of output token1
    /// @param _token0OverToken1Price The price of the pair expressed as token0 over token1 with 18 decimals of precision
    /// @param _token1PurchaseFee The purchase fee for the token0, given as a percentage with 18 decimals of precision i.e. 1e16 = 1%
    /// @return _amount0In The amount of input token0
    /// @return _token1PurchaseFeeAmount The amount of accumulated fees for the purchase of token1
    function getAmount0In(
        uint256 _amount1Out,
        uint256 _token0OverToken1Price,
        uint256 _token1PurchaseFee
    ) public pure returns (uint256 _amount0In, uint256 _token1PurchaseFeeAmount) {
        _token1PurchaseFeeAmount = (_amount1Out * _token1PurchaseFee) / FEE_PRECISION;

        // Always round up the fee
        if (_token1PurchaseFeeAmount * FEE_PRECISION < _amount1Out * _token1PurchaseFee) _token1PurchaseFeeAmount += 1;

        _amount0In = ((_amount1Out + _token1PurchaseFeeAmount) * _token0OverToken1Price) / PRICE_PRECISION;

        // Always round up the amount going into the contract
        if (_amount0In * PRICE_PRECISION < (_amount1Out + _token1PurchaseFeeAmount) * _token0OverToken1Price) {
            _amount0In += 1;
        }
    }

    /// @notice The ```getAmount1In``` function calculates the amount of input token1In required for a given amount token0Out
    /// @param _amount0Out The amount of output token0
    /// @param _token0OverToken1Price The price of the pair expressed as token0 over token1 with 18 decimals of precision
    /// @param _token0PurchaseFee The purchase fee for the token1, given as a percentage with 18 decimals of precision i.e. 1e16 = 1%
    /// @return _amount1In The amount of input token1
    /// @return _token0FeeAmount The amount of purchase fees for the token0
    function getAmount1In(
        uint256 _amount0Out,
        uint256 _token0OverToken1Price,
        uint256 _token0PurchaseFee
    ) public pure returns (uint256 _amount1In, uint256 _token0FeeAmount) {
        _token0FeeAmount = (_amount0Out * _token0PurchaseFee) / FEE_PRECISION;

        // Always round up the fee
        if (_token0FeeAmount * FEE_PRECISION < _amount0Out * _token0PurchaseFee) _token0FeeAmount += 1;

        _amount1In = ((_amount0Out + _token0FeeAmount) * PRICE_PRECISION) / _token0OverToken1Price;

        // Always round up the amount going into the contract
        if (_amount1In * _token0OverToken1Price < (_amount0Out + _token0FeeAmount) * PRICE_PRECISION) _amount1In += 1;
    }

    /// @notice The ```getAmount0Out``` function calculates the amount of output token0Out returned from a given amount of input token1In
    /// @param _amount1In The amount of input token1
    /// @param _token0OverToken1Price The price of the pair expressed as token0 over token1 with 18 decimals of precision
    /// @param _token0PurchaseFee The purchase fee for the token0, given as a percentage with 18 decimals of precision i.e. 1e16 = 1%
    /// @return _amount0Out The amount of output token0
    /// @return _token0PurchaseFeeAmount The amount of purchase fees for the token0
    function getAmount0Out(
        uint256 _amount1In,
        uint256 _token0OverToken1Price,
        uint256 _token0PurchaseFee
    ) public pure returns (uint256 _amount0Out, uint256 _token0PurchaseFeeAmount) {
        // NOTE:  price and fee must be chosen such that we dont get an overflow during the multiplication here
        _token0PurchaseFeeAmount =
            (_amount1In * _token0OverToken1Price * _token0PurchaseFee) /
            (FEE_PRECISION * PRICE_PRECISION);

        // Always round up the fee
        if (
            _token0PurchaseFeeAmount * FEE_PRECISION * PRICE_PRECISION <
            _amount1In * _token0OverToken1Price * _token0PurchaseFee
        ) _token0PurchaseFeeAmount += 1;

        _amount0Out = ((_amount1In * _token0OverToken1Price) / PRICE_PRECISION) - _token0PurchaseFeeAmount;
    }

    /// @notice The ```getAmount1Out``` function calculates the amount of output token1Out returned from a given amount of input token0In
    /// @param _amount0In The amount of input token0
    /// @param _token0OverToken1Price The price of the pair expressed as token0 over token1 with 18 decimals of precision
    /// @param _token1PurchaseFee The purchase fee for the token1, given as a percentage with 18 decimals of precision i.e. 1e16 = 1%
    /// @return _amount1Out The amount of output token1
    /// @return _token1PurchaseFeeAmount The amount of purchase fees for the token1
    function getAmount1Out(
        uint256 _amount0In,
        uint256 _token0OverToken1Price,
        uint256 _token1PurchaseFee
    ) public pure returns (uint256 _amount1Out, uint256 _token1PurchaseFeeAmount) {
        _token1PurchaseFeeAmount =
            (_amount0In * PRICE_PRECISION * _token1PurchaseFee) /
            (FEE_PRECISION * _token0OverToken1Price);

        // Always round up the fee
        if (
            _token1PurchaseFeeAmount * FEE_PRECISION * _token0OverToken1Price <
            _amount0In * PRICE_PRECISION * _token1PurchaseFee
        ) _token1PurchaseFeeAmount += 1;

        _amount1Out = ((_amount0In * PRICE_PRECISION) / _token0OverToken1Price) - _token1PurchaseFeeAmount;
    }

    //==============================================================================
    // External Stateful Functions
    //==============================================================================

    /// @notice The ```swap``` function swaps tokens in the pair
    /// @dev This function is meant to be called by an external contract which performs important safety checks
    /// @param _amount0Out The amount of token0 to send out
    /// @param _amount1Out The amount of token1 to send out
    /// @param _to The address to send the tokens to
    /// @param _data The data to send to the callback
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _to, bytes memory _data) public nonReentrant {
        _requireSenderIsRole({ _role: APPROVED_SWAPPER });

        // Checks: input sanitation, force one amountOut to be 0, and the other to be > 0
        if ((_amount0Out != 0 && _amount1Out != 0) || (_amount0Out == 0 && _amount1Out == 0)) {
            revert InvalidSwapAmounts();
        }

        // Cache information about the pair for gas savings
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _token0OverToken1Price = calculatePrice({
            _priceLastUpdated: _swapStorage.priceLastUpdated,
            _timestamp: block.timestamp,
            _perSecondInterestRate: _swapStorage.perSecondInterestRate,
            _basePrice: _swapStorage.basePrice
        });

        // Checks: ensure pair not paused
        if (_swapStorage.isPaused) revert PairIsPaused();

        // Checks: proper liquidity available, NOTE: we allow emptying the pair
        if (_amount0Out > _swapStorage.reserve0 || _amount1Out > _swapStorage.reserve1) revert InsufficientLiquidity();

        // Send the tokens (you can only send 1)
        if (_amount0Out > 0) IERC20(_swapStorage.token0).safeTransfer({ to: _to, value: _amount0Out });
        else IERC20(_swapStorage.token1).safeTransfer({ to: _to, value: _amount1Out });

        // Execute the callback (if relevant)
        if (_data.length > 0) {
            IUniswapV2Callee(_to).uniswapV2Call({
                sender: msg.sender,
                amount0: _amount0Out,
                amount1: _amount1Out,
                data: _data
            });
        }

        // Take snapshot of balances
        uint256 _finalToken0Balance = IERC20(_swapStorage.token0).balanceOf({ account: address(this) });
        uint256 _finalToken1Balance = IERC20(_swapStorage.token1).balanceOf({ account: address(this) });

        // Calculate how many tokens were transferred
        uint256 _token0In = _finalToken0Balance > (_swapStorage.reserve0 - _amount0Out)
            ? _finalToken0Balance - (_swapStorage.reserve0 - _amount0Out)
            : 0;
        uint256 _token1In = _finalToken1Balance > (_swapStorage.reserve1 - _amount1Out)
            ? _finalToken1Balance - (_swapStorage.reserve1 - _amount1Out)
            : 0;

        {
            // Create local scope
            uint256 _token0PurchaseFee;
            uint256 _token1PurchaseFee;

            // Checks: Final invariant, ensure that we received the correct amount of tokens
            if (_amount0Out > 0) {
                // we are sending token0 out, receiving token1 In
                uint256 _expectedAmount1In;
                (_expectedAmount1In, _token0PurchaseFee) = getAmount1In({
                    _amount0Out: _amount0Out,
                    _token0OverToken1Price: _token0OverToken1Price,
                    _token0PurchaseFee: _swapStorage.token0PurchaseFee
                });
                if (_expectedAmount1In > _token1In) revert InsufficientInputAmount();
            } else {
                // we are sending token1 out, receiving token0 in
                uint256 _expectedAmount0In;
                (_expectedAmount0In, _token1PurchaseFee) = getAmount0In({
                    _amount1Out: _amount1Out,
                    _token0OverToken1Price: _token0OverToken1Price,
                    _token1PurchaseFee: _swapStorage.token1PurchaseFee
                });
                if (_expectedAmount0In > _token0In) revert InsufficientInputAmount();
            }

            // emit event
            emit SwapFees({ token0FeesAccumulated: _token0PurchaseFee, token1FeesAccumulated: _token1PurchaseFee });

            // Calculate new fees + reserves in memory struct
            _swapStorage.token0FeesAccumulated += _token0PurchaseFee.toUint128();
            _swapStorage.token1FeesAccumulated += _token1PurchaseFee.toUint128();
            _swapStorage.reserve0 = (_finalToken0Balance - _swapStorage.token0FeesAccumulated).toUint112();
            _swapStorage.reserve1 = (_finalToken1Balance - _swapStorage.token1FeesAccumulated).toUint112();
        }

        // Effects: update storage
        _getPointerToStorage().swapStorage = _swapStorage;

        // emit event
        emit Sync({ reserve0: _swapStorage.reserve0, reserve1: _swapStorage.reserve1 });

        // emit event
        emit Swap({
            sender: msg.sender,
            amount0In: _token0In,
            amount1In: _token1In,
            amount0Out: _amount0Out,
            amount1Out: _amount1Out,
            to: _to
        });
    }

    /// @notice The ```swapExactTokensForTokens``` function swaps an exact amount of input tokenIn for an amount of output tokenOut
    /// @param _amountIn The amount of input tokenIn
    /// @param _amountOutMin The minimum amount of output tokenOut
    /// @param _path The path of the tokens
    /// @param _to The address to send the tokens to
    /// @param _deadline The deadline for the swap
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory _amounts) {
        // Checks: block.timestamp must be less than deadline
        if (_deadline < block.timestamp) revert Expired();

        address _tokenIn = _path[0];
        address _tokenOut = _path[1];
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _token0OverToken1Price = calculatePrice({
            _priceLastUpdated: _swapStorage.priceLastUpdated,
            _timestamp: block.timestamp,
            _perSecondInterestRate: _swapStorage.perSecondInterestRate,
            _basePrice: _swapStorage.basePrice
        });

        // Checks: path length is 2 && path must contain token0 and token1 only
        requireValidPath({ _path: _path, _token0: _swapStorage.token0, _token1: _swapStorage.token1 });

        // Calculations: determine amounts based on path
        (uint256 _amountOut, ) = _tokenOut == _swapStorage.token0
            ? getAmount0Out({
                _amount1In: _amountIn,
                _token0OverToken1Price: _token0OverToken1Price,
                _token0PurchaseFee: _swapStorage.token0PurchaseFee
            })
            : getAmount1Out({
                _amount0In: _amountIn,
                _token0OverToken1Price: _token0OverToken1Price,
                _token1PurchaseFee: _swapStorage.token1PurchaseFee
            });

        // Checks: amountOut must not be smaller than the amountOutMin
        if (_amountOut < _amountOutMin) revert InsufficientOutputAmount();

        // Interactions: transfer tokens from msg.sender to this contract
        IERC20(_tokenIn).safeTransferFrom({ from: msg.sender, to: address(this), value: _amountIn });

        // Effects: swap tokens
        if (_tokenOut == _swapStorage.token0) {
            swap({ _amount0Out: _amountOut, _amount1Out: 0, _to: _to, _data: new bytes(0) });
        } else {
            swap({ _amount0Out: 0, _amount1Out: _amountOut, _to: _to, _data: new bytes(0) });
        }

        // Set return variables
        _amounts = new uint256[](2);
        _amounts[0] = _amountIn;
        _amounts[1] = _amountOut;
    }

    /// @notice The ```swapTokensForExactTokens``` function swaps an amount of output tokenOut for an exact amount of input tokenIn
    /// @param _amountOut The amount of output tokenOut
    /// @param _amountInMax The maximum amount of input tokenIn
    /// @param _path The path of the tokens
    /// @param _to The address to send the tokens to
    /// @param _deadline The deadline for the swap
    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory _amounts) {
        // Checks: block.timestamp must be less than deadline
        if (_deadline < block.timestamp) revert Expired();

        address _tokenIn = _path[0];
        address _tokenOut = _path[1];
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _token0OverToken1Price = calculatePrice({
            _priceLastUpdated: _swapStorage.priceLastUpdated,
            _timestamp: block.timestamp,
            _perSecondInterestRate: _swapStorage.perSecondInterestRate,
            _basePrice: _swapStorage.basePrice
        });

        // Checks: path length is 2 && path must contain token0 and token1 only
        requireValidPath({ _path: _path, _token0: _swapStorage.token0, _token1: _swapStorage.token1 });

        // Calculations: determine amounts based on path
        (uint256 _amountIn, ) = _tokenIn == _swapStorage.token0
            ? getAmount0In({
                _amount1Out: _amountOut,
                _token0OverToken1Price: _token0OverToken1Price,
                _token1PurchaseFee: _swapStorage.token1PurchaseFee
            })
            : getAmount1In({
                _amount0Out: _amountOut,
                _token0OverToken1Price: _token0OverToken1Price,
                _token0PurchaseFee: _swapStorage.token0PurchaseFee
            });

        // Checks: amountInMax must be larger or equal to than the amountIn
        if (_amountIn > _amountInMax) revert ExcessiveInputAmount();

        // Interactions: transfer tokens from msg.sender to this contract
        IERC20(_tokenIn).safeTransferFrom({ from: msg.sender, to: address(this), value: _amountIn });

        // Effects: swap tokens
        if (_tokenOut == _swapStorage.token0) {
            swap({ _amount0Out: _amountOut, _amount1Out: 0, _to: _to, _data: new bytes(0) });
        } else {
            swap({ _amount0Out: 0, _amount1Out: _amountOut, _to: _to, _data: new bytes(0) });
        }

        // Set return variables
        _amounts = new uint256[](2);
        _amounts[0] = _amountIn;
        _amounts[1] = _amountOut;
    }

    /// @notice The ```sync``` function syncs the reserves of the pair
    /// @dev This function is used to sync the reserves of the pair
    function sync() external {
        SwapStorage memory _storage = _getPointerToStorage().swapStorage;
        _sync({
            _token0Balance: IERC20(_storage.token0).balanceOf(address(this)),
            _token1Balance: IERC20(_storage.token1).balanceOf(address(this)),
            _token0FeesAccumulated: _storage.token0FeesAccumulated,
            _token1FeesAccumulated: _storage.token1FeesAccumulated
        });
        // emit event
        emit Sync({ reserve0: _storage.reserve0, reserve1: _storage.reserve1 });
    }

    /// @notice The ```_sync``` function syncs the reserves + fees of the pair
    /// @param _token0Balance The balance of token0
    /// @param _token1Balance The balance of token1
    /// @param _token0FeesAccumulated The amount of token0 fees accumulated
    /// @param _token1FeesAccumulated The amount of token1 fees accumulated
    function _sync(
        uint256 _token0Balance,
        uint256 _token1Balance,
        uint256 _token0FeesAccumulated,
        uint256 _token1FeesAccumulated
    ) internal {
        _getPointerToStorage().swapStorage.reserve0 = (_token0Balance - _token0FeesAccumulated).toUint112();
        _getPointerToStorage().swapStorage.reserve1 = (_token1Balance - _token1FeesAccumulated).toUint112();
        _getPointerToStorage().swapStorage.token0FeesAccumulated = _token0FeesAccumulated.toUint128();
        _getPointerToStorage().swapStorage.token1FeesAccumulated = _token1FeesAccumulated.toUint128();
    }

    /// @notice The ```calculatePrice``` function calculates the price of the pair using a simple interest rate model
    /// @param _priceLastUpdated The timestamp of the last price update
    /// @param _timestamp The timestamp for which we'd like to calculate the price
    /// @param _perSecondInterestRate The per second interest rate
    /// @param _basePrice The base price of the pair
    /// @return _price The price of the pair
    function calculatePrice(
        uint256 _priceLastUpdated,
        uint256 _timestamp,
        int256 _perSecondInterestRate,
        uint256 _basePrice
    ) public pure returns (uint256 _price) {
        // Calculate the time elapsed since the last price update
        uint256 timeElapsed = _timestamp - _priceLastUpdated;

        // Calculate the price
        _price = _perSecondInterestRate >= 0
            ? ((_basePrice * (PRICE_PRECISION + uint256(_perSecondInterestRate) * timeElapsed)) / PRICE_PRECISION)
            : ((_basePrice * (PRICE_PRECISION - (uint256(-_perSecondInterestRate) * timeElapsed))) / PRICE_PRECISION);
    }

    /// @notice The ```getPrice``` function returns the current price of the pair
    /// @return _currentPrice The current price of the pair
    function getPrice() public view virtual returns (uint256 _currentPrice) {
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _priceLastUpdated = _swapStorage.priceLastUpdated;
        uint256 _currentTimestamp = block.timestamp;
        uint256 _basePrice = _swapStorage.basePrice;
        int256 _perSecondInterestRate = _swapStorage.perSecondInterestRate;
        _currentPrice = calculatePrice({
            _priceLastUpdated: _priceLastUpdated,
            _timestamp: _currentTimestamp,
            _perSecondInterestRate: _perSecondInterestRate,
            _basePrice: _basePrice
        });
    }

    /// @notice The ```getPrice``` function returns the price of the pair at a given timestamp
    /// @param _timestamp The timestamp for which we'd like to get the price
    /// @return _price The price of the pair at the given timestamp
    function getPrice(uint256 _timestamp) public view returns (uint256 _price) {
        SwapStorage memory _swapStorage = _getPointerToStorage().swapStorage;
        uint256 _priceLastUpdated = _swapStorage.priceLastUpdated;
        uint256 _basePrice = _swapStorage.basePrice;
        int256 _perSecondInterestRate = _swapStorage.perSecondInterestRate;
        _price = calculatePrice({
            _priceLastUpdated: _priceLastUpdated,
            _timestamp: _timestamp,
            _perSecondInterestRate: _perSecondInterestRate,
            _basePrice: _basePrice
        });
    }

    //==============================================================================
    // Events
    //==============================================================================

    /// @notice The ```SetTokenReceiver``` event is emitted when the token receiver is set
    /// @param tokenReceiver The address of the token receiver
    event SetTokenReceiver(address indexed tokenReceiver);

    /// @notice The ```SetApprovedSwapper``` event is emitted when the approved swapper is set
    /// @param approvedSwapper The address of the approved swapper
    /// @param isApproved The boolean value indicating whether the swapper is approved
    event SetApprovedSwapper(address indexed approvedSwapper, bool isApproved);

    /// @notice The ```SetFeeBounds``` event is emitted when the fee bounds are set
    /// @param minToken0PurchaseFee The minimum purchase fee for token0
    /// @param maxToken0PurchaseFee The maximum purchase fee for token0
    /// @param minToken1PurchaseFee The minimum purchase fee for token1
    /// @param maxToken1PurchaseFee The maximum purchase fee for token1
    event SetFeeBounds(
        uint256 minToken0PurchaseFee,
        uint256 maxToken0PurchaseFee,
        uint256 minToken1PurchaseFee,
        uint256 maxToken1PurchaseFee
    );

    /// @notice The ```SetTokenPurchaseFees``` event is emitted when the token purchase fees are set
    /// @param token0PurchaseFee The purchase fee for token0
    /// @param token1PurchaseFee The purchase fee for token1
    event SetTokenPurchaseFees(uint256 token0PurchaseFee, uint256 token1PurchaseFee);

    /// @notice The ```RemoveTokens``` event is emitted when tokens are removed
    /// @param tokenAddress The address of the token
    /// @param amount The amount of tokens to remove
    event RemoveTokens(address indexed tokenAddress, uint256 amount);

    /// @notice The ```SetPaused``` event is emitted when the pair is paused
    /// @param isPaused The boolean value indicating whether the pair is paused
    event SetPaused(bool isPaused);

    /// @notice Emitted when the price bounds are set
    /// @param minBasePrice The minimum allowed initial base price
    /// @param maxBasePrice The maximum allowed initial base price
    /// @param minAnnualizedInterestRate The minimum allowed annualized interest rate
    /// @param maxAnnualizedInterestRate The maximum allowed annualized interest rate
    event SetOraclePriceBounds(
        uint256 minBasePrice,
        uint256 maxBasePrice,
        int256 minAnnualizedInterestRate,
        int256 maxAnnualizedInterestRate
    );

    /// @notice Emitted when the price is configured
    /// @param basePrice The base price of the pair
    /// @param annualizedInterestRate The annualized interest rate
    event ConfigureOraclePrice(uint256 basePrice, int256 annualizedInterestRate);

    /// @notice Emitted when a swap is executed
    /// @param sender The address of the sender
    /// @param amount0In The amount of token0 in
    /// @param amount1In The amount of token1 in
    /// @param amount0Out The amount of token0 out
    /// @param amount1Out The amount of token1 out
    /// @param to The address of the recipient
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /// @notice Emitted when fees are accumulated
    /// @param token0FeesAccumulated The amount of token0 accumulated as fees
    /// @param token1FeesAccumulated The amount of token1 accumulated as fees
    event SwapFees(uint256 token0FeesAccumulated, uint256 token1FeesAccumulated);

    /// @notice Emitted when the reserves are synced
    /// @param reserve0 The reserve of token0
    /// @param reserve1 The reserve of token1
    event Sync(uint256 reserve0, uint256 reserve1);

    /// @notice Emitted when the fee receiver is set
    /// @param feeReceiver The address of the fee receiver
    event SetFeeReceiver(address indexed feeReceiver);

    // ============================================================================================
    // Errors
    // ============================================================================================

    /// @notice Emitted when an invalid token is passed to a function
    error InvalidTokenAddress();

    /// @notice Emitted when an invalid path is passed to a function
    error InvalidPath();

    /// @notice Emitted when an invalid path length is passed to a function
    error InvalidPathLength();

    /// @notice Emitted when both amounts cannot be non-zero
    error InvalidSwapAmounts();

    /// @notice Emitted when the deadline is passed
    error Expired();

    /// @notice Emitted when the reserve is insufficient
    error InsufficientLiquidity();

    /// @notice Emitted when the token purchase fee is invalid
    error InvalidToken0PurchaseFee();

    /// @notice Emitted when the token1 purchase fee is invalid
    error InvalidToken1PurchaseFee();

    /// @notice Emitted when the input amount is excessive
    error ExcessiveInputAmount();

    /// @notice Emitted when the output amount is insufficient
    error InsufficientOutputAmount();

    /// @notice Emitted when the input amount is insufficient
    error InsufficientInputAmount();

    /// @notice Emitted when the pair is paused
    error PairIsPaused();

    /// @notice Emitted when the price is out of bounds
    error BasePriceOutOfBounds();

    /// @notice Emitted when the annualized interest rate is out of bounds
    error AnnualizedInterestRateOutOfBounds();

    /// @notice Emitted when the min base price is greater than the max base price
    error MinBasePriceGreaterThanMaxBasePrice();

    /// @notice Emitted when the min annualized interest rate is greater than the max annualized interest rate
    error MinAnnualizedInterestRateGreaterThanMax();

    /// @notice Emitted when the min token0 purchase fee is greater than the max token0 purchase fee
    error MinToken0PurchaseFeeGreaterThanMax();

    /// @notice Emitted when the min token1 purchase fee is greater than the max token1 purchase fee
    error MinToken1PurchaseFeeGreaterThanMax();

    /// @notice Emitted when there are insufficient tokens available for withrawal
    error InsufficientTokens();

    /// @notice Emitted when the decimals of the tokens are invalid during initialization
    error IncorrectDecimals();
}
