// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/mocks/MockUSDC.sol";

interface Vm {
    function envUint(string calldata name) external view returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DeployMockUSDC {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (MockUSDC deployed) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        deployed = new MockUSDC();
        vm.stopBroadcast();
    }
}
