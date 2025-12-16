// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

library AgoraStableSwapFactory {
    struct AgoraStableSwapDefaultParamsStorage {
        address initialDefaultAdminAddress;
        address initialDefaultWhitelister;
        address initialDefaultFeeSetter;
        address initialDefaultTokenRemover;
        address initialDefaultPauser;
        address initialDefaultPriceSetter;
        address initialDefaultTokenReceiver;
        address initialDefaultFeeReceiver;
    }

    struct CreatePairArgs {
        address token0;
        uint256 token0Decimals;
        uint256 minToken0PurchaseFee;
        uint256 maxToken0PurchaseFee;
        uint256 token0PurchaseFee;
        address token1;
        uint256 token1Decimals;
        uint256 minToken1PurchaseFee;
        uint256 maxToken1PurchaseFee;
        uint256 token1PurchaseFee;
        uint256 minBasePrice;
        uint256 maxBasePrice;
        uint256 basePrice;
        int256 minAnnualizedInterestRate;
        int256 maxAnnualizedInterestRate;
        int256 annualizedInterestRate;
    }

    struct PairData {
        address pairAddress;
        TokenInfo token0;
        TokenInfo token1;
    }

    struct TokenInfo {
        address tokenAddress;
        string name;
        string symbol;
        uint256 decimals;
    }

    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
    }
}

interface IAgoraStableSwapFactory {
    struct InitializeParams {
        address initialStableSwapImplementation;
        address initialStableSwapProxyAdminAddress;
        address initialFactoryAccessControlManager;
        address initialImplementationSetter;
        address[] initialApprovedDeployers;
        address initialDefaultAdminAddress;
        address initialDefaultWhitelister;
        address initialDefaultFeeSetter;
        address initialDefaultTokenRemover;
        address initialDefaultPauser;
        address initialDefaultPriceSetter;
        address initialDefaultTokenReceiver;
        address initialDefaultFeeReceiver;
    }

    error AddressIsNotRole(string role);
    error CannotRemoveLastManager();
    error DecimalDeltaTooLarge();
    error IdenticalAddresses();
    error InvalidInitialization();
    error InvalidTokenOrder();
    error NotInitializing();
    error PairExists();
    error RoleNameTooLong();
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);
    error ZeroAddress();

    event Initialized(uint64 version);
    event PairCreated(address indexed token0, address indexed token1, address pair);
    event RoleAssigned(string indexed role, address indexed address_);
    event RoleRevoked(string indexed role, address indexed address_);
    event SetApprovedDeployer(address indexed approvedDeployer, bool isApproved);
    event SetDefaultRoles(
        address initialAdminAddress,
        address initialWhitelister,
        address initialFeeSetter,
        address initialTokenRemover,
        address initialPauser,
        address initialPriceSetter,
        address initialTokenReceiver,
        address initialFeeReceiver
    );
    event SetPair(address indexed token0, address indexed token1, address pair);
    event SetStableSwapImplementation(address indexed newImplementation);

    function ACCESS_CONTROL_MANAGER_ROLE() external view returns (string memory);
    function AGORA_ACCESS_CONTROL_STORAGE_SLOT() external view returns (bytes32);
    function AGORA_STABLE_SWAP_FACTORY_STORAGE_SLOT() external view returns (bytes32);
    function APPROVED_DEPLOYER() external view returns (string memory);
    function IMPLEMENTATION_SETTER_ROLE() external view returns (string memory);
    function allPairs() external view returns (address[] memory _pairs);
    function assignRole(string memory _role, address _newAddress, bool _addRole) external;
    function computePairDeploymentAddress(
        address _tokenA,
        address _tokenB
    ) external view returns (address _pairDeploymentAddress);
    function createPair(AgoraStableSwapFactory.CreatePairArgs memory _pairArgs) external returns (address pair);
    function getAgoraStableSwapDefaultParamsStorage()
        external
        view
        returns (AgoraStableSwapFactory.AgoraStableSwapDefaultParamsStorage memory);
    function getAllPairData() external view returns (AgoraStableSwapFactory.PairData[] memory);
    function getAllRoles() external view returns (string[] memory _roles);
    function getPairFromTokens(address _token0, address _token1) external view returns (address);
    function getRoleMembers(string memory _role) external view returns (address[] memory _members);
    function hasRole(string memory _role, address _address) external view returns (bool);
    function implementationAddress() external view returns (address);
    function initialize(InitializeParams memory _params) external;
    function name() external pure returns (string memory);
    function proxyAdminAddress() external view returns (address);
    function setApprovedDeployers(address[] memory _approvedDeployers, bool _setApproved) external;
    function setDefaultRoles(
        address _initialAdminAddress,
        address _initialWhitelister,
        address _initialFeeSetter,
        address _initialTokenRemover,
        address _initialPauser,
        address _initialPriceSetter,
        address _initialTokenReceiver,
        address _initialFeeReceiver
    ) external;
    function setPair(address _tokenA, address _tokenB, address _pairAddress) external;
    function setStableSwapImplementation(address _newImplementation) external;
    function sortTokens(address _tokenA, address _tokenB) external pure returns (address _token0, address _token1);
    function stableSwapImplementation() external view returns (address);
    function stableSwapProxyAdmin() external view returns (address);
    function version() external pure returns (AgoraStableSwapFactory.Version memory _version);
}
