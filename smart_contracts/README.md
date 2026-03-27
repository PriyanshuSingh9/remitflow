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
- The setup uses no nested repos or vendored Solidity dependencies.
- Tests use a local cheatcode interface, so the workspace stays self-contained.
- The contract emits the PRD event shape and moves USDC with `transferFrom`.

