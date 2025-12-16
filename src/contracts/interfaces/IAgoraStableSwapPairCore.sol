// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

interface IAgoraStableSwapPairCore {
    error AddressIsNotRole(string role);
    error AnnualizedInterestRateOutOfBounds();
    error BasePriceOutOfBounds();
    error CannotRemoveLastManager();
    error ExcessiveInputAmount();
    error Expired();
    error IncorrectDecimals();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InsufficientTokens();
    error InvalidInitialization();
    error InvalidPath();
    error InvalidPathLength();
    error InvalidSwapAmounts();
    error InvalidToken0PurchaseFee();
    error InvalidToken1PurchaseFee();
    error InvalidTokenAddress();
    error MinAnnualizedInterestRateGreaterThanMax();
    error MinBasePriceGreaterThanMaxBasePrice();
    error MinToken0PurchaseFeeGreaterThanMax();
    error MinToken1PurchaseFeeGreaterThanMax();
    error NotInitializing();
    error PairIsPaused();
    error PriceExpired();
    error ReentrancyGuardReentrantCall();
    error RoleNameTooLong();
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);
    error SafeERC20FailedOperation(address token);

    event AddLiquidity(address indexed tokenAddress, uint256 amount);
    event CollectFees(address indexed tokenAddress, uint256 amount);
    event ConfigureOraclePrice(uint256 basePrice, int256 annualizedInterestRate);
    event Initialized(uint64 version);
    event RemoveTokens(address indexed tokenAddress, uint256 amount);
    event RoleAssigned(string indexed role, address indexed address_);
    event RoleRevoked(string indexed role, address indexed address_);
    event SetApprovedSwapper(address indexed approvedSwapper, bool isApproved);
    event SetFeeBounds(
        uint256 minToken0PurchaseFee,
        uint256 maxToken0PurchaseFee,
        uint256 minToken1PurchaseFee,
        uint256 maxToken1PurchaseFee
    );
    event SetFeeReceiver(address indexed feeReceiver);
    event SetOraclePriceBounds(
        uint256 minBasePrice,
        uint256 maxBasePrice,
        int256 minAnnualizedInterestRate,
        int256 maxAnnualizedInterestRate
    );
    event SetPaused(bool isPaused);
    event SetTokenPurchaseFees(uint256 token0PurchaseFee, uint256 token1PurchaseFee);
    event SetTokenReceiver(address indexed tokenReceiver);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event SwapFees(uint256 token0PurchaseFee, uint256 token1PurchaseFee);
    event Sync(uint256 reserve0, uint256 reserve1);

    function ACCESS_CONTROL_MANAGER_ROLE() external view returns (string memory);
    function AGORA_ACCESS_CONTROL_STORAGE_SLOT() external view returns (bytes32);
    function AGORA_STABLE_SWAP_STORAGE_SLOT() external view returns (bytes32);
    function APPROVED_SWAPPER() external view returns (string memory);
    function FEE_PRECISION() external view returns (uint256);
    function FEE_SETTER_ROLE() external view returns (string memory);
    function PAUSER_ROLE() external view returns (string memory);
    function PRICE_PRECISION() external view returns (uint256);
    function PRICE_SETTER_ROLE() external view returns (string memory);
    function TOKEN_REMOVER_ROLE() external view returns (string memory);
    function WHITELISTER_ROLE() external view returns (string memory);
    function addLiquidity(address _tokenAddress, uint256 _amount) external;
    function assignRole(string memory _role, address _newAddress, bool _addRole) external;
    function calculatePrice(
        uint256 _priceLastUpdated,
        uint256 _timestamp,
        int256 _perSecondInterestRate,
        uint256 _basePrice
    ) external pure returns (uint256 _price);
    function getAllRoles() external view returns (string[] memory _roles);
    function getAmount0In(
        uint256 _amount1Out,
        uint256 _token0OverToken1Price,
        uint256 _token1PurchaseFee
    ) external pure returns (uint256 _amount0In, uint256 _token1PurchaseFeeAmount);
    function getAmount0Out(
        uint256 _amount1In,
        uint256 _token0OverToken1Price,
        uint256 _token0PurchaseFee
    ) external pure returns (uint256 _amount0Out, uint256 _token0PurchaseFeeAmount);
    function getAmount1In(
        uint256 _amount0Out,
        uint256 _token0OverToken1Price,
        uint256 _token0PurchaseFee
    ) external pure returns (uint256 _amount1In, uint256 _token0FeeAmount);
    function getAmount1Out(
        uint256 _amount0In,
        uint256 _token0OverToken1Price,
        uint256 _token1PurchaseFee
    ) external pure returns (uint256 _amount1Out, uint256 _token1PurchaseFeeAmount);
    function getPrice() external view returns (uint256 _currentPrice);
    function getPrice(uint256 _timestamp) external view returns (uint256 _price);
    function getRoleMembers(string memory _role) external view returns (address[] memory _members);
    function hasRole(string memory _role, address _address) external view returns (bool);
    function implementationAddress() external view returns (address);
    function proxyAdminAddress() external view returns (address);
    function requireValidPath(address[] memory _path, address _token0, address _token1) external pure;
    function swap(uint256 _amount0Out, uint256 _amount1Out, address _to, bytes memory _data) external;
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory _amounts);
    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) external returns (uint256[] memory _amounts);
    function sync() external;
}
