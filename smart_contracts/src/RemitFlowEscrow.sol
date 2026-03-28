// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title RemitFlowEscrow
/// @notice Escrow contract for cross-border remittance. Locks USDC until off-ramp
///         succeeds (release) or fails (refund). The operator is the only address
///         that can release or refund an escrow.
contract RemitFlowEscrow {
    using SafeERC20 for IERC20;

    // ─── Errors ────────────────────────────────────────────────────────
    error InvalidUSDC();
    error InvalidOperator();
    error InvalidReceiver();
    error ZeroAmount();
    error OnlyOperator();
    error EscrowNotFound();
    error EscrowAlreadySettled();
    error InvalidEscrowState();
    error NotTimedOut();

    // ─── State ─────────────────────────────────────────────────────────
    IERC20 public immutable usdc;
    address public immutable operator;

    enum EscrowState {
        Deposited,         // Funds locked, waiting for off-ramp readiness
        ReadyForFunding,   // Off-ramp confirmed payout readiness
        Released,          // Funds sent to off-ramp wallet
        Refunded           // Funds returned to sender
    }

    struct Escrow {
        address sender;
        address receiver;
        uint256 amount;
        EscrowState state;
        uint256 depositTimestamp;
    }

    uint256 public nextEscrowId;
    mapping(uint256 => Escrow) public escrows;

    uint256 public constant ESCROW_TIMEOUT = 24 hours;

    // ─── Events ────────────────────────────────────────────────────────
    event EscrowDeposited(
        uint256 indexed escrowId,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp
    );

    event EscrowReadyForFunding(uint256 indexed escrowId, uint256 timestamp);

    event EscrowReleased(
        uint256 indexed escrowId,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp
    );

    event EscrowRefunded(
        uint256 indexed escrowId,
        address indexed sender,
        uint256 amount,
        uint256 timestamp
    );

    // ─── Modifiers ─────────────────────────────────────────────────────
    modifier onlyOperator() {
        if (msg.sender != operator) revert OnlyOperator();
        _;
    }

    // ─── Constructor ───────────────────────────────────────────────────
    constructor(address _usdc, address _operator) {
        if (_usdc == address(0) || _usdc.code.length == 0) revert InvalidUSDC();
        if (_operator == address(0)) revert InvalidOperator();
        usdc = IERC20(_usdc);
        operator = _operator;
    }

    // ─── Phase 1: Operator deposits on behalf of a sender ──────────────
    /// @notice Operator deposits USDC into escrow on behalf of the sender.
    function operatorDeposit(
        address sender,
        address receiver,
        uint256 amount
    ) external onlyOperator returns (uint256 escrowId) {
        if (receiver == address(0) || receiver == sender) revert InvalidReceiver();
        if (amount == 0) revert ZeroAmount();

        // Pull USDC from operator
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        escrowId = nextEscrowId++;
        escrows[escrowId] = Escrow({
            sender: sender,
            receiver: receiver,
            amount: amount,
            state: EscrowState.Deposited,
            depositTimestamp: block.timestamp
        });

        emit EscrowDeposited(escrowId, sender, receiver, amount, block.timestamp);
    }

    // ─── Phase 2: User deposits directly ───────────────────────────────
    /// @notice User deposits their own USDC into escrow.
    function depositToEscrow(
        address receiver,
        uint256 amount
    ) external returns (uint256 escrowId) {
        if (receiver == address(0) || receiver == msg.sender) revert InvalidReceiver();
        if (amount == 0) revert ZeroAmount();

        // Pull USDC from the sender
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        escrowId = nextEscrowId++;
        escrows[escrowId] = Escrow({
            sender: msg.sender,
            receiver: receiver,
            amount: amount,
            state: EscrowState.Deposited,
            depositTimestamp: block.timestamp
        });

        emit EscrowDeposited(escrowId, msg.sender, receiver, amount, block.timestamp);
    }

    // ─── Readiness: Backend confirms off-ramp is ready ──────────────────
    /// @notice Confirms that the off-ramp is ready to pay out fiat.
    function confirmReadyForFunding(uint256 escrowId) external onlyOperator {
        Escrow storage e = escrows[escrowId];
        if (e.amount == 0) revert EscrowNotFound();
        if (e.state != EscrowState.Deposited) revert InvalidEscrowState();

        e.state = EscrowState.ReadyForFunding;

        emit EscrowReadyForFunding(escrowId, block.timestamp);
    }

    // ─── Release: off-ramp succeeded, send USDC to receiver ───────────
    /// @notice Releases escrowed USDC to the receiver. Only operator can call.
    function releaseEscrow(uint256 escrowId) external onlyOperator {
        Escrow storage e = escrows[escrowId];
        if (e.amount == 0) revert EscrowNotFound();
        if (e.state == EscrowState.Released || e.state == EscrowState.Refunded) revert EscrowAlreadySettled();
        if (e.state != EscrowState.ReadyForFunding) revert InvalidEscrowState();

        e.state = EscrowState.Released;
        usdc.safeTransfer(e.receiver, e.amount);

        emit EscrowReleased(escrowId, e.receiver, e.amount, block.timestamp);
    }

    // ─── Refund: off-ramp failed or manual intervention ───────────────
    /// @notice Refunds escrowed USDC back to the sender. Only operator can call.
    function refundEscrow(uint256 escrowId) external onlyOperator {
        Escrow storage e = escrows[escrowId];
        if (e.amount == 0) revert EscrowNotFound();
        if (e.state == EscrowState.Released || e.state == EscrowState.Refunded) revert EscrowAlreadySettled();

        e.state = EscrowState.Refunded;
        usdc.safeTransfer(e.sender, e.amount);

        emit EscrowRefunded(escrowId, e.sender, e.amount, block.timestamp);
    }

    // ─── Timeout Refund: anyone can trigger if timeout exceeded ────────
    /// @notice Refunds escrow if the off-ramp never confirms readiness within ESCROW_TIMEOUT.
    function refundTimedOut(uint256 escrowId) external {
        Escrow storage e = escrows[escrowId];
        if (e.amount == 0) revert EscrowNotFound();
        if (e.state != EscrowState.Deposited) revert InvalidEscrowState();
        if (block.timestamp < e.depositTimestamp + ESCROW_TIMEOUT) revert NotTimedOut();

        e.state = EscrowState.Refunded;
        usdc.safeTransfer(e.sender, e.amount);

        emit EscrowRefunded(escrowId, e.sender, e.amount, block.timestamp);
    }
}

