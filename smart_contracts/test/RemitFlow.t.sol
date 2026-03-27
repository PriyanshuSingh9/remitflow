// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/RemitFlow.sol";
import "../src/mocks/MockUSDC.sol";

interface Vm {
    function prank(address msgSender) external;
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

contract RemitFlowTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockUSDC private usdc;
    RemitFlow private remitFlow;
    address private sender = address(0xA11CE);
    address private receiver = address(0xB0B);

    event Transfer(address indexed sender, address indexed receiver, uint256 usdcAmount, uint256 timestamp);

    function setUp() public {
        usdc = new MockUSDC();
        remitFlow = new RemitFlow(address(usdc));

        usdc.mint(sender, 1_000_000);
        vm.prank(sender);
        usdc.approve(address(remitFlow), type(uint256).max);
    }

    function testTransferUSDC() public {
        setUp();

        vm.expectEmit(true, true, false, true);
        emit Transfer(sender, receiver, 250_000, block.timestamp);

        vm.prank(sender);
        remitFlow.transferUSDC(receiver, 250_000);
    }

    function testRejectsZeroReceiver() public {
        setUp();

        vm.expectRevert(abi.encodeWithSelector(RemitFlow.InvalidReceiver.selector));
        vm.prank(sender);
        remitFlow.transferUSDC(address(0), 1);
    }

    function testRejectsZeroAmount() public {
        setUp();

        vm.expectRevert(abi.encodeWithSelector(RemitFlow.ZeroAmount.selector));
        vm.prank(sender);
        remitFlow.transferUSDC(receiver, 0);
    }

    function testRejectsSelfTransfer() public {
        setUp();

        vm.expectRevert(abi.encodeWithSelector(RemitFlow.InvalidReceiver.selector));
        vm.prank(sender);
        remitFlow.transferUSDC(sender, 1);
    }
}

