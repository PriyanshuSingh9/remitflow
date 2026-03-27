// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract RemitFlow {
    error InvalidReceiver();
    error ZeroAmount();
    error InvalidUSDC();
    error TokenTransferFailed();

    IERC20Minimal public immutable usdc;

    event Transfer(
        address indexed sender,
        address indexed receiver,
        uint256 usdcAmount,
        uint256 timestamp
    );

    constructor(address _usdc) {
        if (_usdc == address(0)) revert InvalidUSDC();
        usdc = IERC20Minimal(_usdc);
    }

    function transferUSDC(address receiver, uint256 amount) external {
        if (receiver == address(0) || receiver == msg.sender) revert InvalidReceiver();
        if (amount == 0) revert ZeroAmount();

        _safeTransferFrom(address(usdc), msg.sender, receiver, amount);

        emit Transfer(msg.sender, receiver, amount, block.timestamp);
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20Minimal.transferFrom.selector, from, to, value)
        );
        if (!success) revert TokenTransferFailed();
        if (data.length != 0 && !abi.decode(data, (bool))) revert TokenTransferFailed();
    }
}

