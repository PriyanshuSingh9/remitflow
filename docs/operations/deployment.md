# Deployment & Network

RemitFlow is currently deployed on the **Polygon Amoy Testnet** for development and hackathon demonstration purposes.

## Network Configuration (Amoy)

- **Network Name**: Polygon Amoy Testnet
- **Chain ID**: `80002`
- **RPC URL**: `https://rpc-amoy.polygon.technology/`
- **Native Token**: `POL` (formerly MATIC)
- **Block Explorer**: [https://amoy.polygonscan.com/](https://amoy.polygonscan.com/)

## Contract Addresses

| Contract | Address |
|---|---|
| **RemitFlowEscrow** | `0x3a0937C9B8eecad82549369187EF1f96BD9B6c23` |
| **USDC (Mock/Testnet)** | `0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582` |

## Deployment Process

### Smart Contracts
Deployed using Foundry's `forge script`.
```bash
forge script script/DeployRemitFlowEscrow.s.sol --rpc-url amoy --broadcast
```

### Backend
Currently hosted on [Platform Name, e.g., Render/Vercel/DigitalOcean].
- **URL**: `https://api.remitflow.io` (Example)
- **CI/CD**: GitHub Actions triggers on `main` branch push.

### Mobile
- **Android**: Distributed via Firebase App Distribution or APK download.
- **iOS**: Available via TestFlight.

## Future Mainnet Migration

For transition to Polygon Mainnet:
1. Update `RPC_URL` to Mainnet endpoint.
2. Deploy `RemitFlowEscrow` on Mainnet and verify.
3. Update `USDC_ADDRESS` to official Circle USDC on Polygon.
4. Transition Transak and OnMeta configurations to Production API keys.
