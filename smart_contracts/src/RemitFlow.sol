// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

pragma solidity ^0.8.18;

contract RemitFlow{
    using SafeERC20 for IERC20;

    error InvalidReceiver();
    error ZeroAmount();

    IERC20 public immutable usdc;

    event Transfer(
        address indexed sender,
        address indexed receiver,
        uint256 usdcAmount,
        uint256 timestamp
    );

    constructor(address _usdc){
        usdc=IERC20(_usdc);
    }


    function transferUSDC(address receiver, uint256 amount) external{
        if (receiver == address(0)) revert InvalidReceiver();
        if (amount == 0) revert ZeroAmount();
        if (receiver == msg.sender) revert InvalidReceiver();

        usdc.safeTransferFrom(msg.sender, receiver, amount);

        emit Transfer(msg.sender, receiver, amount, block.timestamp);
    }
}