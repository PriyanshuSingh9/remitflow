# RemitFlow Smart Contracts

Minimal Foundry workspace for the RemitFlow transfer contract.

## Layout
- `src/RemitFlow.sol`: main transfer contract
- `src/mocks/MockUSDC.sol`: local ERC-20 mock for tests
- `test/RemitFlow.t.sol`: unit tests
- `script/DeployRemitFlow.s.sol`: deployment script

## Requirements
- Foundry installed
- `SHARDEUM_RPC_URL` in `.env` for Shardeum deployment
- `USDC_ADDRESS` and `PRIVATE_KEY` for broadcasting deployment
- OpenZeppelin installed into `lib/`:

```shell
forge install --no-git OpenZeppelin/openzeppelin-contracts
```

## Common commands

```shell
forge build
forge test
forge fmt
forge snapshot
```

## Deploy

```shell
forge script script/DeployRemitFlow.s.sol:DeployRemitFlow --rpc-url $SHARDEUM_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

## Notes
- Solidity dependencies are installed locally with Foundry and are not committed.
- Tests use a local cheatcode interface, so the workspace stays self-contained.
- The contract emits the PRD event shape and moves USDC with `transferFrom`.
