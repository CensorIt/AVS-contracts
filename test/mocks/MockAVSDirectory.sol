// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAVSDirectory {
    mapping(address => bool) public isOperator;
    
    function setOperator(address operator, bool status) external {
        isOperator[operator] = status;
    }
}