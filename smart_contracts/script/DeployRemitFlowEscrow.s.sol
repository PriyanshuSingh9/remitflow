// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/RemitFlowEscrow.sol";

interface Vm {
    function envAddress(string calldata name) external view returns (address);
    function envUint(string calldata name) external view returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DeployRemitFlowEscrow {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (RemitFlowEscrow deployed) {
        address usdc = vm.envAddress("USDC_ADDRESS");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        // msg.sender during broadcast = address derived from PRIVATE_KEY
        // That address becomes the operator (can release/refund escrows)
        deployed = new RemitFlowEscrow(usdc, msg.sender);
        vm.stopBroadcast();
    }
}
