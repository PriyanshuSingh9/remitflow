// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RemitFlow {
    using SafeERC20 for IERC20;

    error InvalidReceiver();
    error ZeroAmount();
    error InvalidUSDC();

    IERC20 public immutable usdc;

    event Transfer(
        address indexed sender,
        address indexed receiver,
        uint256 usdcAmount,
        uint256 timestamp
    );

    constructor(address _usdc) {
        if (_usdc == address(0) || _usdc.code.length == 0) revert InvalidUSDC();
        usdc = IERC20(_usdc);
    }

    function transferUSDC(address receiver, uint256 amount) external {
        if (receiver == address(0) || receiver == msg.sender) revert InvalidReceiver();
        if (amount == 0) revert ZeroAmount();

        usdc.safeTransferFrom(msg.sender, receiver, amount);

        emit Transfer(msg.sender, receiver, amount, block.timestamp);
    }
}
