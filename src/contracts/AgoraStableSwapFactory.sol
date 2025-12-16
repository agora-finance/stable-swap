// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ==================== AgoraStableSwapFactory ========================
// ====================================================================

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { AgoraAccessControl } from "agora-contracts/access-control/AgoraAccessControl.sol";

import { AgoraStableSwapPair, InitializeParams as AgoraStableSwapPairParams } from "./AgoraStableSwapPair.sol";
import { AgoraTransparentUpgradeableProxy, ConstructorParams as AgoraTransparentUpgradeableProxyParams } from "agora-contracts/proxy/AgoraTransparentUpgradeableProxy.sol";
import { Erc1967Implementation } from "agora-contracts/proxy/Erc1967Implementation.sol";
import { ICreateX } from "createx/ICreateX.sol";

/// @notice The ```InitializeParams``` struct is used to initialize the AgoraStableSwapFactory
/// @param initialStableSwapImplementation The implementation address for the `AgoraStableSwapPair` proxies
/// @param initialStableSwapProxyAdminAddress The ProxyAdmin address for the `AgoraStableSwapPair` proxies deployed by the factory
/// @param initialFactoryAccessControlManager The address that controls the factory
/// @param initialImplementationSetter The address that controls the `AgoraStableSwapPair` implementation used by the factory
/// @param initialApprovedDeployers The addresses that are initially approved to deploy new pairs
/// @param initialDefaultAdminAddress The default address of the initial admin
/// @param initialDefaultWhitelister The default address of the initial whitelister
/// @param initialDefaultFeeSetter The default address of the initial fee setter
/// @param initialDefaultTokenRemover The default address of the initial token remover
/// @param initialDefaultPauser The default address of the initial pauser
/// @param initialDefaultPriceSetter The default address of the initial price setter
/// @param initialDefaultTokenReceiver The default address of the initial token receiver
/// @param initialDefaultFeeReceiver The default address of the initial fee receiver
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

/// @title AgoraStableSwapFactory
/// @notice The AgoraStableSwapFactory is a contract that manages the deployment of AgoraStableSwapPair contracts
/// @author Agora
contract AgoraStableSwapFactory is AgoraAccessControl, Initializable, Erc1967Implementation {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for uint256;
    using SafeCast for *;

    /// @notice the address of the CREATEX_DEPLOYER contract
    address constant CREATEX_DEPLOYER = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    /// @notice the APPROVED_DEPLOYER identifier
    string public constant APPROVED_DEPLOYER = "APPROVED_DEPLOYER";

    /// @notice the IMPLEMENTATION_SETTER_ROLE identifier
    string public constant IMPLEMENTATION_SETTER_ROLE = "IMPLEMENTATION_SETTER_ROLE";

    //==============================================================================
    // Storage Structs
    //==============================================================================

    /// @notice The ```AgoraStableSwapDefaultParamsStorage``` struct is used to store the initial roles of the `AgoraStableSwapPair`
    /// @param initialDefaultAdminAddress The default address of the initial admin
    /// @param initialDefaultWhitelister The default address of the initial whitelister
    /// @param initialDefaultFeeSetter The default address of the initial fee setter
    /// @param initialDefaultTokenRemover The default address of the initial token remover
    /// @param initialDefaultPauser The default address of the initial pauser
    /// @param initialDefaultPriceSetter The default address of the initial price setter
    /// @param initialDefaultTokenReceiver The default address of the initial token receiver
    /// @param initialDefaultFeeReceiver The default address of the initial fee receiver
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

    /// @notice The ```AgoraStableSwapFactoryStorage``` struct stores the main state of the factory
    /// @param allPairs A EnumerableSet containing addresses of all pairs created by this factory
    /// @param getPair A mapping from token pairs to their corresponding swap pair contract address
    /// @param stableSwapImplementation The implementation contract address used for all proxy pairs
    /// @param proxyAdminAddress The admin address for all proxy pairs
    /// @param pairDefaultParamsStorage Default parameters used when initializing new pairs
    struct AgoraStableSwapFactoryStorage {
        EnumerableSet.AddressSet allPairs;
        mapping(address => mapping(address => address)) getPair;
        address stableSwapImplementation;
        address proxyAdminAddress;
        AgoraStableSwapDefaultParamsStorage pairDefaultParamsStorage;
    }

    //==============================================================================
    // Constructor & Initalization Functions
    //==============================================================================

    constructor() {
        _disableInitializers();
    }

    /// @notice The ```initialize``` function initializes the AgoraStableSwapFactory contract with initial parameters
    /// @dev This function can only be called once due to the initializer modifier
    /// @param _params The initialization parameters struct
    function initialize(InitializeParams memory _params) external initializer {
        // Set the admin role
        _initializeAgoraAccessControl({ _initialAdminAddress: _params.initialFactoryAccessControlManager });

        // `proxyAdminAddress` is the proxy admin for the proxy contracts generated with this factory
        _getPointerToFactoryStorage().proxyAdminAddress = _params.initialStableSwapProxyAdminAddress;

        // We temporarily set the manager role to the sender to set the defaultValues on initialization
        _assignRole({ _role: ACCESS_CONTROL_MANAGER_ROLE, _newAddress: msg.sender, _addRole: true });

        // We temporarily set the implementation setter role to the sender to set the pair implementation address
        _assignRole({ _role: IMPLEMENTATION_SETTER_ROLE, _newAddress: msg.sender, _addRole: true });

        // Effects: set the pair implementation address
        setStableSwapImplementation(_params.initialStableSwapImplementation);

        // Remove privileges from deployer
        _assignRole({ _role: IMPLEMENTATION_SETTER_ROLE, _newAddress: msg.sender, _addRole: false });

        // We set the `initialApprovedDeployers` as approved deployers
        setApprovedDeployers(_params.initialApprovedDeployers, true);

        // We set the pair implementation setter role
        _assignRole({
            _role: IMPLEMENTATION_SETTER_ROLE,
            _newAddress: _params.initialImplementationSetter,
            _addRole: true
        });

        // We set the default roles for the AgoraStableSwapPair Proxy initialization
        setDefaultRoles({
            _initialAdminAddress: _params.initialDefaultAdminAddress,
            _initialWhitelister: _params.initialDefaultWhitelister,
            _initialFeeSetter: _params.initialDefaultFeeSetter,
            _initialTokenRemover: _params.initialDefaultTokenRemover,
            _initialPauser: _params.initialDefaultPauser,
            _initialPriceSetter: _params.initialDefaultPriceSetter,
            _initialTokenReceiver: _params.initialDefaultTokenReceiver,
            _initialFeeReceiver: _params.initialDefaultFeeReceiver
        });

        // Remove privileges from deployer
        if (_params.initialFactoryAccessControlManager != msg.sender) {
            _assignRole({ _role: ACCESS_CONTROL_MANAGER_ROLE, _newAddress: msg.sender, _addRole: false });
        }
    }

    //==============================================================================
    // Erc 7201: UnstructuredNamespace Storage Functions
    //==============================================================================

    /// @notice The ```AGORA_STABLE_SWAP_FACTORY_STORAGE_SLOT``` is the storage slot for the AgoraStableSwapFactoryStorage struct
    /// @dev keccak256(abi.encode(uint256(keccak256("AgoraStableSwapFactoryStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant AGORA_STABLE_SWAP_FACTORY_STORAGE_SLOT =
        0x024be988c51836176a4af0f43e497ce34fbb4aad290e797943ba9ded87630000;

    /// @notice The ```_getPointerToStorage``` function returns a pointer to the AgoraStableSwapFactoryStorage struct
    /// @return $ A pointer to the AgoraStableSwapFactoryStorage struct
    function _getPointerToFactoryStorage() internal pure returns (AgoraStableSwapFactoryStorage storage $) {
        /// @solidity memory-safe-assembly
        assembly {
            $.slot := AGORA_STABLE_SWAP_FACTORY_STORAGE_SLOT
        }
    }

    //==============================================================================
    // Privileged Configuration Functions
    //==============================================================================

    /// @notice The ```setDefaultRoles``` function is used to store the default roles to initialize the AgoraStableSwapPair
    /// @dev Only the manager can set the default roles
    /// @param _initialAdminAddress The address of the initial admin
    /// @param _initialWhitelister The address of the initial whitelister
    /// @param _initialFeeSetter The address of the initial fee setter
    /// @param _initialTokenRemover The address of the initial token remover
    /// @param _initialPauser The address of the initial pauser
    /// @param _initialPriceSetter The address of the initial price setter
    /// @param _initialTokenReceiver The address of the initial token receiver
    /// @param _initialFeeReceiver The address of the initial fee receiver
    function setDefaultRoles(
        address _initialAdminAddress,
        address _initialWhitelister,
        address _initialFeeSetter,
        address _initialTokenRemover,
        address _initialPauser,
        address _initialPriceSetter,
        address _initialTokenReceiver,
        address _initialFeeReceiver
    ) public {
        // Checks: Only the manager can set the default roles
        _requireSenderIsRole({ _role: ACCESS_CONTROL_MANAGER_ROLE });

        AgoraStableSwapDefaultParamsStorage storage storageStruct = _getPointerToFactoryStorage()
            .pairDefaultParamsStorage;
        storageStruct.initialDefaultAdminAddress = _initialAdminAddress;
        storageStruct.initialDefaultWhitelister = _initialWhitelister;
        storageStruct.initialDefaultFeeSetter = _initialFeeSetter;
        storageStruct.initialDefaultTokenRemover = _initialTokenRemover;
        storageStruct.initialDefaultPauser = _initialPauser;
        storageStruct.initialDefaultPriceSetter = _initialPriceSetter;
        storageStruct.initialDefaultTokenReceiver = _initialTokenReceiver;
        storageStruct.initialDefaultFeeReceiver = _initialFeeReceiver;

        // Emit event for default roles being set
        emit SetDefaultRoles({
            initialAdminAddress: _initialAdminAddress,
            initialWhitelister: _initialWhitelister,
            initialFeeSetter: _initialFeeSetter,
            initialTokenRemover: _initialTokenRemover,
            initialPauser: _initialPauser,
            initialPriceSetter: _initialPriceSetter,
            initialTokenReceiver: _initialTokenReceiver,
            initialFeeReceiver: _initialFeeReceiver
        });
    }

    /// @notice The ```setApprovedDeployer``` function sets the approved deployers
    /// @dev Only the manager can set the approved deployers
    /// @param _approvedDeployers The addresses of the approved deployers
    /// @param _setApproved The boolean value indicating whether the deployers are approved
    function setApprovedDeployers(address[] memory _approvedDeployers, bool _setApproved) public {
        // Checks: Only the manager can set the approved deployers
        _requireSenderIsRole({ _role: ACCESS_CONTROL_MANAGER_ROLE });

        for (uint256 i = 0; i < _approvedDeployers.length; i++) {
            // Effects: Set the isApproved state
            _assignRole({ _role: APPROVED_DEPLOYER, _newAddress: _approvedDeployers[i], _addRole: _setApproved });

            // emit event
            emit SetApprovedDeployer({ approvedDeployer: _approvedDeployers[i], isApproved: _setApproved });
        }
    }

    /// @notice The ```setStableSwapImplementation``` function updates the pair implementation address
    /// @dev Only the implementation setter can update the pair implementation address
    /// @param _newImplementation The address of the new pair implementation
    function setStableSwapImplementation(address _newImplementation) public {
        // Checks: Only the implementation setter can set the implementation
        _requireSenderIsRole({ _role: IMPLEMENTATION_SETTER_ROLE });

        // Effects: Set the new implementation
        _getPointerToFactoryStorage().stableSwapImplementation = _newImplementation;

        // emit event
        emit SetStableSwapImplementation({ newImplementation: _newImplementation });
    }

    /// @notice The ```setPair``` function updates the storage of a token pair
    /// @dev Only the manager can update the storage of a token pair
    /// @param _tokenA the first token in the pair
    /// @param _tokenB the second token in the pair
    /// @param _pairAddress the address that the pair storage will be assigned to
    function setPair(address _tokenA, address _tokenB, address _pairAddress) external {
        // Checks: Only the manager can modify the pairs
        _requireSenderIsRole({ _role: ACCESS_CONTROL_MANAGER_ROLE });

        // Checks: tokens in swap should be different
        if (_tokenA == _tokenB) revert IdenticalAddresses();
        // Sort the tokens
        (address _token0, address _token1) = sortTokens(_tokenA, _tokenB);

        // Access the storage
        AgoraStableSwapFactoryStorage storage factoryStorage = _getPointerToFactoryStorage();

        // Effects: Modify storage from `allPairs`
        if (_pairAddress == address(0)) {
            address _pairToRemove = factoryStorage.getPair[_token0][_token1];
            factoryStorage.allPairs.remove(_pairToRemove);
        } else {
            factoryStorage.allPairs.add(_pairAddress);
        }

        // Effects: Modify storage from `getPair` on both directions
        factoryStorage.getPair[_token0][_token1] = _pairAddress;
        factoryStorage.getPair[_token1][_token0] = _pairAddress;

        // Emits the SetPair event
        emit SetPair(_token0, _token1, _pairAddress);
    }

    //==============================================================================
    //  FactoryStorage View Functions
    //==============================================================================

    /// @notice returns the storage of the factory default parameters
    function getAgoraStableSwapDefaultParamsStorage() public view returns (AgoraStableSwapDefaultParamsStorage memory) {
        return _getPointerToFactoryStorage().pairDefaultParamsStorage;
    }

    /// @notice returns the implementation address for the `AgoraStableSwapPair` proxies
    function stableSwapImplementation() public view returns (address) {
        return _getPointerToFactoryStorage().stableSwapImplementation;
    }

    /// @notice returns the ProxyAdmin contract address for the `AgoraStableSwapPair` proxies deployed by the factory
    function stableSwapProxyAdmin() public view returns (address) {
        return _getPointerToFactoryStorage().proxyAdminAddress;
    }

    /// @notice returns all pairs deployed by the factory
    function allPairs() public view returns (address[] memory _pairs) {
        return _getPointerToFactoryStorage().allPairs.values();
    }

    /// @notice The ```TokenInfo``` struct holds basic information about a token
    /// @param tokenAddress The smart contract address of the token
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param decimals The number of decimals used by the token
    struct TokenInfo {
        address tokenAddress;
        string name;
        string symbol;
        uint256 decimals;
    }

    /// @notice The ```PairData``` struct is used to store addresses of a pair and its constituent tokens
    /// @param pairAddress The address of the pair contract
    /// @param token0 Information about the first token
    /// @param token1 Information about the second token
    struct PairData {
        address pairAddress;
        TokenInfo token0;
        TokenInfo token1;
    }

    function getAllPairData() public view returns (PairData[] memory) {
        address[] memory deployedPairs = allPairs();
        PairData[] memory pairData = new PairData[](deployedPairs.length);
        for (uint256 i = 0; i < deployedPairs.length; i++) {
            AgoraStableSwapPair pairAddress = AgoraStableSwapPair(deployedPairs[i]);
            IERC20Metadata token0 = IERC20Metadata(pairAddress.token0());
            IERC20Metadata token1 = IERC20Metadata(pairAddress.token1());

            pairData[i] = PairData({
                pairAddress: address(pairAddress),
                token0: TokenInfo({
                    tokenAddress: address(token0),
                    name: token0.name(),
                    decimals: token0.decimals(),
                    symbol: token0.symbol()
                }),
                token1: TokenInfo({
                    tokenAddress: address(token1),
                    name: token1.name(),
                    decimals: token1.decimals(),
                    symbol: token1.symbol()
                })
            });
        }
        return pairData;
    }

    /// @notice returns the pair address for the given tokens
    /// @param _token0 the address of the first token in the pair
    /// @param _token1 the address of the second token in the pair
    function getPairFromTokens(address _token0, address _token1) public view returns (address) {
        // The pairs are stored in both (_token0, _token1) and (_token1, _token0) so no need to sort the tokens.
        return _getPointerToFactoryStorage().getPair[_token0][_token1];
    }

    //==============================================================================
    // Pure Helper Functions
    //==============================================================================

    /// @notice The ```name``` function returns the name of the pairFactory
    /// @return _name The name of the pairFactory
    function name() public pure returns (string memory) {
        return "AgoraStableSwapFactory";
    }

    /// @notice returns the sorted tokens in ascending order based on their addresses
    /// @param _tokenA the first token in the pair
    /// @param _tokenB the second token in the pair
    function sortTokens(address _tokenA, address _tokenB) public pure returns (address _token0, address _token1) {
        (_token0, _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    //==============================================================================
    // View Functions
    //==============================================================================

    /// @notice sorts and computes the pair deployment address based on the input tokens
    /// @param _tokenA the first token in the pair
    /// @param _tokenB the second token in the pair
    function computePairDeploymentAddress(
        address _tokenA,
        address _tokenB
    ) public view returns (address _pairDeploymentAddress) {
        // Checks: tokens in swap should be different
        if (_tokenA == _tokenB) revert IdenticalAddresses();
        // Sort the tokens
        (address _token0, address _token1) = sortTokens(_tokenA, _tokenB);

        // Checks: None of the tokens should be zero address
        if (_token0 == address(0)) revert ZeroAddress();

        bytes32 _salt = _generateSalt(_token0, _token1);
        // `this` is the factory proxy
        bytes32 _guardedSalt = keccak256(abi.encodePacked(bytes32(uint256(uint160(address(this)))), _salt));
        _pairDeploymentAddress = ICreateX(CREATEX_DEPLOYER).computeCreate3Address({ salt: _guardedSalt });
    }

    /// @notice computes the salt for the pair deployment address based on the input tokens
    /// @param _token0 the address of the first token in the pair
    /// @param _token1 the address of the second token in the pair
    function _generateSalt(address _token0, address _token1) internal view returns (bytes32 _salt) {
        _salt = bytes32(
            abi.encodePacked(
                address(this),
                hex"00", // no cross-chain redeploy protection
                bytes11(keccak256(abi.encodePacked(_token0, _token1)))
            )
        );
    }

    /// @notice generates the `AgoraStableSwapPairParams` struct for a new pair with the given parameters
    /// @param _pairArgs The parameters for creating a new pair
    function _generateStableSwapPairParams(
        CreatePairArgs memory _pairArgs
    ) internal view returns (AgoraStableSwapPairParams memory _pairParams) {
        AgoraStableSwapDefaultParamsStorage memory _defaultParamsStorage = _getPointerToFactoryStorage()
            .pairDefaultParamsStorage;
        // Gets the constructor arguments for the pair.
        _pairParams = AgoraStableSwapPairParams({
            token0: _pairArgs.token0,
            token0Decimals: _pairArgs.token0Decimals.toUint8(),
            token1: _pairArgs.token1,
            token1Decimals: _pairArgs.token1Decimals.toUint8(),
            minToken0PurchaseFee: _pairArgs.minToken0PurchaseFee,
            maxToken0PurchaseFee: _pairArgs.maxToken0PurchaseFee,
            minToken1PurchaseFee: _pairArgs.minToken1PurchaseFee,
            maxToken1PurchaseFee: _pairArgs.maxToken1PurchaseFee,
            token0PurchaseFee: _pairArgs.token0PurchaseFee,
            token1PurchaseFee: _pairArgs.token1PurchaseFee,
            initialAdminAddress: _defaultParamsStorage.initialDefaultAdminAddress,
            initialWhitelister: _defaultParamsStorage.initialDefaultWhitelister,
            initialFeeSetter: _defaultParamsStorage.initialDefaultFeeSetter,
            initialTokenRemover: _defaultParamsStorage.initialDefaultTokenRemover,
            initialPauser: _defaultParamsStorage.initialDefaultPauser,
            initialPriceSetter: _defaultParamsStorage.initialDefaultPriceSetter,
            initialTokenReceiver: _defaultParamsStorage.initialDefaultTokenReceiver,
            initialFeeReceiver: _defaultParamsStorage.initialDefaultFeeReceiver,
            minBasePrice: _pairArgs.minBasePrice,
            maxBasePrice: _pairArgs.maxBasePrice,
            minAnnualizedInterestRate: _pairArgs.minAnnualizedInterestRate,
            maxAnnualizedInterestRate: _pairArgs.maxAnnualizedInterestRate,
            basePrice: _pairArgs.basePrice,
            annualizedInterestRate: _pairArgs.annualizedInterestRate
        });
    }

    //==============================================================================
    // External Stateful Functions
    //==============================================================================

    /// @notice The `CreatePairArgs` struct is used for creating a new stable swap pair
    /// @param token0 The address of the first token in the pair
    /// @param token0Decimals The number of decimals for token0
    /// @param minToken0PurchaseFee The minimum purchase fee for token0, 18 decimals precision, max value 1
    /// @param maxToken0PurchaseFee The maximum purchase fee for token0, 18 decimals precision, max value 1
    /// @param token0PurchaseFee The purchase fee for token0, 18 decimals precision, max value 1
    /// @param token1 The address of the second token in the pair
    /// @param token1Decimals The number of decimals for token1
    /// @param minToken1PurchaseFee The minimum purchase fee for token1, 18 decimals precision, max value 1
    /// @param maxToken1PurchaseFee The maximum purchase fee for token1, 18 decimals precision, max value 1
    /// @param token1PurchaseFee The purchase fee for token1, 18 decimals precision, max value 1
    /// @param minBasePrice The minimum base price for the pair, 18 decimals precision, min/max value determined by difference between decimals of token0 and token1
    /// @param maxBasePrice The maximum base price for the pair, 18 decimals precision, min/max value determined by difference between decimals of token0 and token1
    /// @param basePrice The base price for the pair, 18 decimals precision, limited by token0 and token1 decimals
    /// @param minAnnualizedInterestRate The minimum annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
    /// @param maxAnnualizedInterestRate The maximum annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
    /// @param annualizedInterestRate The annualized interest rate for the pair, 18 decimals precision, given as number i.e. 1e16 = 1%
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

    /// @notice creates a new pair with the given parameters
    /// @param _pairArgs The parameters for creating a new pair
    function createPair(CreatePairArgs memory _pairArgs) external returns (address pair) {
        // Checks: Only the deployer can create a new pair
        _requireSenderIsRole({ _role: APPROVED_DEPLOYER });

        // Checks: tokens in swap should be different
        if (_pairArgs.token0 == _pairArgs.token1) revert IdenticalAddresses();

        // Sorts the variables according to their token address order
        (address _expectedToken0, ) = sortTokens(_pairArgs.token0, _pairArgs.token1);

        //Checks: The tokens should be ordered correctly
        if (_expectedToken0 != _pairArgs.token0) revert InvalidTokenOrder();

        // Checks: None of the tokens should be zero address
        if (_expectedToken0 == address(0)) revert ZeroAddress();

        // Checks: The pair must not already exist
        if (getPairFromTokens(_pairArgs.token0, _pairArgs.token1) != address(0)) revert PairExists();

        // Checks: The delta between the decimals must not be more than 12
        if (
            _pairArgs.token0Decimals > _pairArgs.token1Decimals + 12 ||
            _pairArgs.token1Decimals > _pairArgs.token0Decimals + 12
        ) revert DecimalDeltaTooLarge();

        // Gets the default parameters for the stable swap pair
        AgoraStableSwapPairParams memory _pairParams = _generateStableSwapPairParams({ _pairArgs: _pairArgs });

        // Gets the initialization data for the pair
        bytes memory _pairInitializationData = abi.encodeWithSelector(
            AgoraStableSwapPair.initialize.selector,
            _pairParams
        );

        // Sets the parameters for the proxy
        bytes memory _constructorArgs = abi.encode(
            AgoraTransparentUpgradeableProxyParams({
                logic: _getPointerToFactoryStorage().stableSwapImplementation,
                proxyAdminAddress: _getPointerToFactoryStorage().proxyAdminAddress,
                data: _pairInitializationData
            })
        );

        // Gets the creation code
        bytes memory bytecode = abi.encodePacked(type(AgoraTransparentUpgradeableProxy).creationCode, _constructorArgs);

        bytes32 _salt = _generateSalt(_pairArgs.token0, _pairArgs.token1);

        // Deploys the proxy admin with create3 (deployer-agnostic)
        pair = ICreateX(CREATEX_DEPLOYER).deployCreate3({ salt: _salt, initCode: bytecode });

        // Sets the pair address in the registry
        _getPointerToFactoryStorage().getPair[_pairArgs.token0][_pairArgs.token1] = pair;
        _getPointerToFactoryStorage().getPair[_pairArgs.token1][_pairArgs.token0] = pair;

        _getPointerToFactoryStorage().allPairs.add(pair);

        // Emits the PairCreated event
        emit PairCreated(_pairArgs.token0, _pairArgs.token1, pair);
        return pair;
    }

    /// @notice The ```Version``` struct is used to represent the version of the AgoraStableSwapFactory
    /// @param major The major version number
    /// @param minor The minor version number
    /// @param patch The patch version number
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
    }

    /// @notice The ```version``` function returns the version of the AgoraStableSwapFactory
    /// @return _version The version of the AgoraStableSwapPair
    function version() public pure returns (Version memory _version) {
        _version = Version({ major: 2, minor: 2, patch: 0 });
    }

    //==============================================================================
    // Events
    //==============================================================================

    /// @notice PairCreated is emitted when a new pair is created
    /// @param token0 The address of the first token in the pair
    /// @param token1 The address of the second token in the pair
    /// @param pair The address of the newly created pair
    event PairCreated(address indexed token0, address indexed token1, address pair);

    /// @notice SetPair is emitted when pair storage is updated
    /// @param token0 The address of the first token in the pair
    /// @param token1 The address of the second token in the pair
    /// @param pair The address to which the pair is updated
    event SetPair(address indexed token0, address indexed token1, address pair);

    /// @param initialAdminAddress The default initial admin address for the proxies created by the factory
    /// @param initialWhitelister The default initial whitelister address for the proxies created by the factory
    /// @param initialFeeSetter The default initial fee setter address for the proxies created by the factory
    /// @param initialTokenRemover The default initial token remover address for the proxies created by the factory
    /// @param initialPauser The default initial pauser address for the proxies created by the factory
    /// @param initialPriceSetter The default initial price setter address for the proxies created by the factory
    /// @param initialTokenReceiver The default initial token receiver address for the proxies created by the factory
    /// @param initialFeeReceiver The default initial fee receiver address for the proxies created by the factory
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

    /// @notice SetApprovedDeployer is emitted when the approved deployer is set.
    /// @param approvedDeployer The address of the approved deployer.
    /// @param isApproved Whether the deployer is approved or not.
    event SetApprovedDeployer(address indexed approvedDeployer, bool isApproved);

    /// @notice SetStableSwapImplementation is emitted when the implementation is set
    /// @param newImplementation The address of the new implementation
    event SetStableSwapImplementation(address indexed newImplementation);

    // ============================================================================================
    // Errors
    // ============================================================================================

    /// @notice IdenticalAddresses is thrown when the token0 and token1 are the same address.
    error IdenticalAddresses();

    /// @notice ZeroAddress is thrown when the address is zero.
    error ZeroAddress();

    /// @notice PairExists is thrown when the pair already exists.
    error PairExists();

    /// @notice DecimalDeltaTooLarge is thrown when the delta between the decimals of the tokens is invalid.
    error DecimalDeltaTooLarge();

    /// @notice InvalidTokenOrder is thrown when the token order is invalid.
    error InvalidTokenOrder();
}
