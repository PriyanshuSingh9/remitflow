# External Integrations

RemitFlow integrates with industry-leading providers to bridge the gap between traditional finance (TradFi) and decentralized finance (DeFi).

## 1. Transak (On-Ramp)

**Role**: Converts USD (Bank/Card) to USDC on Polygon.

- **Integration Method**: Hosted WebView Widget.
- **Flow**:
    1. User enters amount in RemitFlow.
    2. App opens Transak WebView with `fiatCurrency=USD` and `cryptoCurrency=USDC`.
    3. Transak completes the KYC (if needed) and payment.
    4. Transak sends USDC to the user's deterministic wallet address.
- **Environment**: Sandbox/Testnet for development; Production for Mainnet.

## 2. OnMeta (Off-Ramp)

**Role**: Converts USDC to INR (Bank/UPI).

- **Integration Method**: REST API (Backend-to-Backend).
- **Flow**:
    1. Backend detects `EscrowDeposited` event on-chain.
    2. Backend calls OnMeta's `createOrder` endpoint with the receiver's bank/UPI details.
    3. OnMeta provides a unique deposit address.
    4. RemitFlow backend releases escrowed funds to that address.
    5. OnMeta credits the receiver's bank account in INR.
- **Environment**: OnMeta Sandbox for Amoy Testnet.

## 3. Google OAuth

**Role**: Identity management and wallet derivation base.

- **Provider**: Google Identity Services.
- **Security**: Uses OAuth2 Authorization Code flow. The `sub` (Subject) field from the ID token is used as the entropy source for deterministic wallet generation.

## 4. Polygon (Blockchain)

**Role**: Settlement layer.

- **Network**: Polygon Amoy Testnet.
- **Asset**: USDC (bridged/testnet version).
- **RPC**: Public Polygon RPC or dedicated providers like Alchemy/Infura.
- **Explorer**: [PolygonScan Amoy](https://amoy.polygonscan.com/).
