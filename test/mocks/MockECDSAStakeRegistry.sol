// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockECDSAStakeRegistry {
    mapping(address => bool) public operatorStatus;
    bytes4 public validSignatureResponse;

    function setOperatorRegistered(address operator, bool status) external {
        operatorStatus[operator] = status;
    }

    function operatorRegistered(address operator) external view returns (bool) {
        return operatorStatus[operator];
    }

    function setIsValidSignatureResponse(bytes4 response) external {
        validSignatureResponse = response;
    }

    function isValidSignature(bytes32, bytes memory) external view returns (bytes4) {
        return validSignatureResponse;
    }
}