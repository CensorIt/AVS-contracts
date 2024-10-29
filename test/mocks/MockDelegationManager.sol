// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockDelegationManager {
    mapping(address => bool) public isDelegated;
    
    function setDelegationStatus(address operator, bool status) external {
        isDelegated[operator] = status;
    }
}