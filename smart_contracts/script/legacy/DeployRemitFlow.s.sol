// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/legacy/RemitFlow.sol";

interface Vm {
    function envAddress(string calldata name) external view returns (address);
    function envUint(string calldata name) external view returns (uint256);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DeployRemitFlow {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (RemitFlow deployed) {
        address usdc = vm.envAddress("USDC_ADDRESS");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        deployed = new RemitFlow(usdc);
        vm.stopBroadcast();
    }
}
