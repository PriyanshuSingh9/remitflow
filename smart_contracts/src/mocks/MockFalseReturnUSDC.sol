// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract MockFalseReturnUSDC {
    string public name = "Mock False USDC";
    string public symbol = "mFUSDC";
    uint8 public decimals = 6;

    function approve(address, uint256) external returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external returns (bool) {
        return false;
    }
}
