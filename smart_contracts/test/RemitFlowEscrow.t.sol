// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../src/RemitFlowEscrow.sol";
import "../src/mocks/MockUSDC.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface Vm {
    function prank(address msgSender) external;
    function expectRevert(bytes calldata revertData) external;
    function expectEmit(bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData) external;
}

contract RemitFlowEscrowTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockUSDC private usdc;
    RemitFlowEscrow private escrow;
    address private operatorAddr = address(0xDEAD);
    address private sender = address(0xA11CE);
    address private receiver = address(0xB0B);

    event EscrowDeposited(uint256 indexed escrowId, address indexed sender, address indexed receiver, uint256 amount, uint256 timestamp);
    event EscrowReadyForFunding(uint256 indexed escrowId, uint256 timestamp);
    event EscrowReleased(uint256 indexed escrowId, address indexed receiver, uint256 amount, uint256 timestamp);
    event EscrowRefunded(uint256 indexed escrowId, address indexed sender, uint256 amount, uint256 timestamp);

    // ─── Helpers ──────────────────────────────────────────────────────
    function _deploy() internal {
        usdc = new MockUSDC();
        // Deploy escrow with operatorAddr as the operator
        vm.prank(operatorAddr);
        escrow = new RemitFlowEscrow(address(usdc), operatorAddr);
    }

    function _fundAndApproveOperator(uint256 amount) internal {
        usdc.mint(operatorAddr, amount);
        vm.prank(operatorAddr);
        usdc.approve(address(escrow), amount);
    }

    function _fundAndApproveSender(uint256 amount) internal {
        usdc.mint(sender, amount);
        vm.prank(sender);
        usdc.approve(address(escrow), amount);
    }

    function _setTimestamp(uint256 timestamp) internal {
        // Foundry cheat code to set block.timestamp
        (bool success, ) = address(vm).call(abi.encodeWithSignature("warp(uint256)", timestamp));
        require(success, "warp failed");
    }

    // ─── Constructor Tests ────────────────────────────────────────────
    function testRejectsZeroUSDCAddress() public {
        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidUSDC.selector));
        new RemitFlowEscrow(address(0), operatorAddr);
    }

    function testRejectsNonContractUSDCAddress() public {
        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidUSDC.selector));
        new RemitFlowEscrow(address(0x1234), operatorAddr);
    }

    function testRejectsZeroOperatorAddress() public {
        _deploy(); // deploy usdc first
        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidOperator.selector));
        new RemitFlowEscrow(address(usdc), address(0));
    }

    // ─── operatorDeposit Tests ────────────────────────────────────────
    function testOperatorDeposit() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.expectEmit(true, true, true, true);
        emit EscrowDeposited(0, sender, receiver, 500_000, block.timestamp);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        // Verify escrow state
        (address s, address r, uint256 a, RemitFlowEscrow.EscrowState state, uint256 ts) = escrow.escrows(id);
        assert(s == sender);
        assert(r == receiver);
        assert(a == 500_000);
        assert(state == RemitFlowEscrow.EscrowState.Deposited);
        assert(ts == block.timestamp);

        // Verify USDC moved to contract
        assert(usdc.balanceOf(address(escrow)) == 500_000);
        assert(usdc.balanceOf(operatorAddr) == 500_000); // 1M - 500K

        // Verify nextEscrowId incremented
        assert(escrow.nextEscrowId() == 1);
    }

    function testOperatorDepositRejectsNonOperator() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.OnlyOperator.selector));
        vm.prank(sender); // not operator
        escrow.operatorDeposit(sender, receiver, 500_000);
    }

    function testOperatorDepositRejectsZeroReceiver() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidReceiver.selector));
        vm.prank(operatorAddr);
        escrow.operatorDeposit(sender, address(0), 500_000);
    }

    function testOperatorDepositRejectsSelfTransfer() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidReceiver.selector));
        vm.prank(operatorAddr);
        escrow.operatorDeposit(sender, sender, 500_000);
    }

    function testOperatorDepositRejectsZeroAmount() public {
        _deploy();

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.ZeroAmount.selector));
        vm.prank(operatorAddr);
        escrow.operatorDeposit(sender, receiver, 0);
    }

    // ─── depositToEscrow Tests (Phase 2, user deposits directly) ──────
    function testDepositToEscrow() public {
        _deploy();
        _fundAndApproveSender(1_000_000);

        vm.expectEmit(true, true, true, true);
        emit EscrowDeposited(0, sender, receiver, 750_000, block.timestamp);

        vm.prank(sender);
        uint256 id = escrow.depositToEscrow(receiver, 750_000);

        (address s, address r, uint256 a, RemitFlowEscrow.EscrowState state, uint256 ts) = escrow.escrows(id);
        assert(s == sender);
        assert(r == receiver);
        assert(a == 750_000);
        assert(state == RemitFlowEscrow.EscrowState.Deposited);
        assert(ts == block.timestamp);

        assert(usdc.balanceOf(address(escrow)) == 750_000);
    }

    function testDepositToEscrowRejectsZeroReceiver() public {
        _deploy();
        _fundAndApproveSender(1_000_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidReceiver.selector));
        vm.prank(sender);
        escrow.depositToEscrow(address(0), 500_000);
    }

    function testDepositToEscrowRejectsSelfTransfer() public {
        _deploy();
        _fundAndApproveSender(1_000_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidReceiver.selector));
        vm.prank(sender);
        address self = sender;
        escrow.depositToEscrow(self, 500_000);
    }

    function testDepositToEscrowRejectsZeroAmount() public {
        _deploy();

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.ZeroAmount.selector));
        vm.prank(sender);
        escrow.depositToEscrow(receiver, 0);
    }

    // ─── confirmReadyForFunding Tests ─────────────────────────────────
    function testConfirmReadyForFunding() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.expectEmit(true, false, false, true);
        emit EscrowReadyForFunding(id, block.timestamp);

        vm.prank(operatorAddr);
        escrow.confirmReadyForFunding(id);

        (, , , RemitFlowEscrow.EscrowState state, ) = escrow.escrows(id);
        assert(state == RemitFlowEscrow.EscrowState.ReadyForFunding);
    }

    function testConfirmReadyForFundingRejectsNonOperator() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.OnlyOperator.selector));
        vm.prank(sender);
        escrow.confirmReadyForFunding(id);
    }

    // ─── releaseEscrow Tests ──────────────────────────────────────────
    function testReleaseEscrow() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        // Must confirm readiness first
        vm.prank(operatorAddr);
        escrow.confirmReadyForFunding(id);

        vm.expectEmit(true, true, false, true);
        emit EscrowReleased(id, receiver, 500_000, block.timestamp);

        vm.prank(operatorAddr);
        escrow.releaseEscrow(id);

        // Verify USDC went to receiver
        assert(usdc.balanceOf(receiver) == 500_000);
        assert(usdc.balanceOf(address(escrow)) == 0);

        // Verify escrow settled
        (, , , RemitFlowEscrow.EscrowState state, ) = escrow.escrows(id);
        assert(state == RemitFlowEscrow.EscrowState.Released);
    }

    function testReleaseEscrowRejectsIfNoReadiness() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.InvalidEscrowState.selector));
        vm.prank(operatorAddr);
        escrow.releaseEscrow(id);
    }

    function testReleaseEscrowRejectsNonOperator() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.prank(operatorAddr);
        escrow.confirmReadyForFunding(id);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.OnlyOperator.selector));
        vm.prank(sender); // not operator
        escrow.releaseEscrow(id);
    }

    function testReleaseEscrowRejectsAlreadySettled() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.prank(operatorAddr);
        escrow.confirmReadyForFunding(id);

        vm.prank(operatorAddr);
        escrow.releaseEscrow(id);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.EscrowAlreadySettled.selector));
        vm.prank(operatorAddr);
        escrow.releaseEscrow(id);
    }

    // ─── refundEscrow Tests ───────────────────────────────────────────
    function testRefundEscrowFromDeposited() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.expectEmit(true, true, false, true);
        emit EscrowRefunded(id, sender, 500_000, block.timestamp);

        vm.prank(operatorAddr);
        escrow.refundEscrow(id);

        assert(usdc.balanceOf(sender) == 500_000);
        (, , , RemitFlowEscrow.EscrowState state, ) = escrow.escrows(id);
        assert(state == RemitFlowEscrow.EscrowState.Refunded);
    }

    function testRefundEscrowFromReady() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.prank(operatorAddr);
        escrow.confirmReadyForFunding(id);

        vm.prank(operatorAddr);
        escrow.refundEscrow(id);

        assert(usdc.balanceOf(sender) == 500_000);
        (, , , RemitFlowEscrow.EscrowState state, ) = escrow.escrows(id);
        assert(state == RemitFlowEscrow.EscrowState.Refunded);
    }

    // ─── refundTimedOut Tests ─────────────────────────────────────────
    function testRefundTimedOut() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        uint256 timeout = escrow.ESCROW_TIMEOUT();
        _setTimestamp(block.timestamp + timeout + 1);

        vm.expectEmit(true, true, false, true);
        emit EscrowRefunded(id, sender, 500_000, block.timestamp);

        // Anyone can call
        vm.prank(address(0xBEEF));
        escrow.refundTimedOut(id);

        assert(usdc.balanceOf(sender) == 500_000);
        (, , , RemitFlowEscrow.EscrowState state, ) = escrow.escrows(id);
        assert(state == RemitFlowEscrow.EscrowState.Refunded);
    }

    function testRefundTimedOutRejectsBeforeTimeout() public {
        _deploy();
        _fundAndApproveOperator(1_000_000);

        vm.prank(operatorAddr);
        uint256 id = escrow.operatorDeposit(sender, receiver, 500_000);

        uint256 timeout = escrow.ESCROW_TIMEOUT();
        _setTimestamp(block.timestamp + timeout - 1);

        vm.expectRevert(abi.encodeWithSelector(RemitFlowEscrow.NotTimedOut.selector));
        escrow.refundTimedOut(id);
    }

    // ─── Multi-escrow Tests ───────────────────────────────────────────
    function testMultipleEscrowsIndependent() public {
        _deploy();
        _fundAndApproveOperator(2_000_000);

        vm.prank(operatorAddr);
        uint256 id1 = escrow.operatorDeposit(sender, receiver, 500_000);

        vm.prank(operatorAddr);
        uint256 id2 = escrow.operatorDeposit(sender, receiver, 300_000);

        assert(id1 == 0);
        assert(id2 == 1);
        assert(escrow.nextEscrowId() == 2);

        // Release first (after confirmation)
        vm.prank(operatorAddr);
        escrow.confirmReadyForFunding(id1);
        vm.prank(operatorAddr);
        escrow.releaseEscrow(id1);

        // Refund second
        vm.prank(operatorAddr);
        escrow.refundEscrow(id2);

        assert(usdc.balanceOf(receiver) == 500_000);
        assert(usdc.balanceOf(sender) == 300_000);
        assert(usdc.balanceOf(address(escrow)) == 0);
    }
}

