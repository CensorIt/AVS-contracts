// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockRewardsCoordinator {
    uint256 public rewardsAmount;
    
    function setRewardsAmount(uint256 amount) external {
        rewardsAmount = amount;
    }
}