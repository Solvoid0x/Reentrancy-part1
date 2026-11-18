// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrossFunctionLab is ReentrancyGuard {

    mapping(address => uint256) private balances;
    mapping(address => uint256) private rewards;
    mapping(address => bool) private rewardClaimed;

    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Zero deposit");

        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {

        uint256 amount = balances[msg.sender];

        require(amount > 0, "No balance");

        balances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{
            value: amount
        }("");

        require(success, "Transfer failed");
    }

    function claimReward() external nonReentrant {

        require(
            balances[msg.sender] >= 1 ether,
            "Insufficient balance"
        );

        require(
            !rewardClaimed[msg.sender],
            "Reward already claimed"
        );

        rewardClaimed[msg.sender] = true;
        rewards[msg.sender] += 1 ether;
    }

    function getBalance(address user)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        return balances[user];
    }

    function getReward(address user)
        external
        view
        nonReentrantView
        returns (uint256)
    {
        return rewards[user];
    }
}
