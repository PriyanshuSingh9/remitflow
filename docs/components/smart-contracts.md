# Smart Contracts

The core of RemitFlow is the `RemitFlowEscrow` contract, which ensures secure cross-border fund handling.

## RemitFlowEscrow.sol

### Features
- **Escrow Logic**: Funds are locked upon deposit and can only be released to the off-ramp provider or refunded to the sender.
- **Role Based**: Only authorized operators can trigger the release of funds after off-ramp verification.
- **Event Driven**: Emits detailed events for every state change.

### Key Functions

- `deposit(uint256 amount, address receiver)`: Senders call this to lock USDC.
- `release(uint256 escrowId, address offRampWallet)`: Called by the operator to send funds to the off-ramp provider.
- `refund(uint256 escrowId)`: Allows the sender to reclaim funds if the transfer fails or times out (after a safety period).

### Events

```solidity
event EscrowDeposited(uint256 indexed escrowId, address indexed sender, address indexed receiver, uint256 amount);
event EscrowReleased(uint256 indexed escrowId, address indexed offRampWallet, uint256 amount);
event EscrowRefunded(uint256 indexed escrowId, address indexed sender, uint256 amount);
```

## Development & Testing

We use **Foundry** for a robust development lifecycle.

- **Location**: `smart_contracts/src/RemitFlowEscrow.sol`
- **Tests**: `smart_contracts/test/RemitFlowEscrow.t.sol`
- **Deployment Scripts**: `smart_contracts/script/DeployRemitFlowEscrow.s.sol`

### Deployment Command
```bash
forge script script/DeployRemitFlowEscrow.s.sol:DeployRemitFlowEscrow --rpc-url amoy --broadcast --verify
```

## Security Considerations
- The contract uses OpenZeppelin's `SafeERC20` for all token transfers.
- Reentrancy guards are implemented on sensitive functions.
- Timelocks/Safety periods are used for refunds to prevent race conditions during active off-ramps.
