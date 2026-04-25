# RemitFlow — Cross-Border Remittance on Polygon

**Send money home. Fast. Fair. Borderless.**

RemitFlow is a decentralized remittance application built for Hack&Chill 3.0, enabling seamless USD to INR transfers using **USDC** on the **Polygon Amoy Testnet**. By leveraging account abstraction and automated on/off-ramp integrations, RemitFlow removes the complexity of crypto for everyday users.

---

## 🚀 Key Features

- **Walletless Experience**: Sign in with Google. Seamless deterministic local wallet generation using HMAC-SHA256. No seed phrases required.
- **Native On-Ramp**: Purchase USDC directly in-app using USD via **Transak**.
- **Instant Off-Ramp**: Convert received USDC to INR instantly to your bank account or UPI via **OnMeta**.
- **Secure Escrow**: Funds are locked safely in a cross-border smart contract until off-ramp completes.
- **Near-Zero Fees**: Powered by Polygon's high-throughput PoS chain and low-cost transactions.
- **Real-Time Tracking**: Track your transfer status from fiat-in to bank-credit on-chain.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter (Dart) |
| **Blockchain** | Polygon Amoy Testnet |
| **Smart Contract** | Solidity & Foundry (Escrow Contract) |
| **Wallet Abstraction** | Google OAuth + Local Deterministic Wallet |
| **Backend API** | Node.js, Express.js |
| **On-Ramp** | Transak API |
| **Off-Ramp** | OnMeta API |
| **Database** | Neon (Serverless Postgres) + Prisma |

---

## 🔄 Transfer Flow

1. **Initiate**: User A enters the amount ($) and receiver details.
2. **On-Ramp**: We then purchase **USDC** via Transak inside the app.
3. **Escrow**: Then deposits USDC into the RemitFlow smart contract escrow.
4. **Validation**: Express backend listens for deposit events and requests off-ramp. 
5. **Credit & Release**: OnMeta converts the USDC to INR. The backend releases the escrow to OnMeta when ready. INR is credited to User B's bank.

---

## 🔧 Polygon Configuration (Amoy Testnet)

- **Network Name**: Polygon Amoy Testnet
- **RPC URL**: `https://rpc-amoy.polygon.technology/`
- **Chain ID**: `80002`
- **Symbol**: `POL`
- **Explorer**: [PolygonScan Amoy](https://amoy.polygonscan.com/)

---

## 🚀 Deployed Contract (Amoy Testnet)

The RemitFlow smart contract is live on Polygon Amoy Testnet:

- **Contract Address**: [`0x3a0937C9B8eecad82549369187EF1f96BD9B6c23`](https://amoy.polygonscan.com/address/0x3a0937C9B8eecad82549369187EF1f96BD9B6c23)
- **Network**: Polygon Amoy (Chain ID: 80002)

---

## 🏗️ Getting Started

### Prerequisites
- Flutter SDK installed
- Android/iOS Emulator or physical device
- `.env` file with necessary API keys (Refer to [RemitFlow_PRD.md](./RemitFlow_PRD.md#L309))

### Installation
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd remitflow
   ```
2. Start the Backend:
   ```bash
   cd backend
   npm install
   npm run dev
   ```
3. Run the Mobile App:
   ```bash
   cd ../mobile
   flutter pub get
   flutter run
   ```

---

## 📄 Documentation

For full product requirements, screen lists, and database schema, refer to the [Product Requirements Document (PRD)](./RemitFlow_PRD.md).

---

## 🏆 Hack&Chill 3.0 Hackathon Project
Built with ❤️ on Polygon.