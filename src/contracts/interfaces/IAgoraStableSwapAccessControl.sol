// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

interface IAgoraStableSwapAccessControl {
    error AddressIsNotRole(string role);
    error CannotRemoveLastManager();
    error RoleNameTooLong();

    event RoleAssigned(string indexed role, address indexed address_);
    event RoleRevoked(string indexed role, address indexed address_);

    function ACCESS_CONTROL_MANAGER_ROLE() external view returns (string memory);
    function AGORA_ACCESS_CONTROL_STORAGE_SLOT() external view returns (bytes32);
    function APPROVED_SWAPPER() external view returns (string memory);
    function FEE_SETTER_ROLE() external view returns (string memory);
    function PAUSER_ROLE() external view returns (string memory);
    function PRICE_SETTER_ROLE() external view returns (string memory);
    function TOKEN_REMOVER_ROLE() external view returns (string memory);
    function WHITELISTER_ROLE() external view returns (string memory);
    function assignRole(string memory _role, address _newAddress, bool _addRole) external;
    function getAllRoles() external view returns (string[] memory _roles);
    function getRoleMembers(string memory _role) external view returns (address[] memory _members);
    function hasRole(string memory _role, address _address) external view returns (bool);
}
