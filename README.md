# RemitFlow — Cross-Border Remittance on Polygon

**Send money home. Fast. Fair. Borderless.**

RemitFlow is a decentralized remittance application built for HackCraft 3.0, enabling seamless USD to INR transfers using **USDC** on the **Polygon Amoy Testnet**. By leveraging account abstraction and automated on/off-ramp integrations, RemitFlow removes the complexity of crypto for everyday users.

---

## 🚀 Key Features

- **Walletless Experience**: Sign in with Google or Email via **Web3Auth**. No seed phrases required.
- **Native On-Ramp**: Purchase USDC directly in-app using USD via **Transak**.
- **Instant Off-Ramp**: Convert received USDC to INR instantly to your bank account or UPI via **OnMeta**.
- **Near-Zero Fees**: Powered by Polygon's high-throughput PoS chain and low-cost transactions.
- **Real-Time Tracking**: Track your transfer status from fiat-in to bank-credit on-chain.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | Flutter (Dart) |
| **Blockchain** | Polygon Amoy Testnet |
| **Smart Contract** | Solidity & Foundry |
| **Wallet Abstraction** | Web3Auth Flutter SDK |
| **On-Ramp** | Transak API |
| **Off-Ramp** | OnMeta API |
| **Database** | Neon (Serverless Postgres) |

---

## 🔄 Transfer Flow

1. **Initiate**: User A enters the amount ($) and receiver details.
2. **On-Ramp**: User A purchases **USDC** via Transak inside the app.
3. **Smart Routing**: Our smart contract routes USDC through Polygon DEX to User B.
4. **Off-Ramp**: OnMeta detects USDC in User B's wallet and converts it to **INR**.
5. **Credit**: INR is credited to User B's bank or UPI account.

---

## 🔧 Polygon Configuration (Amoy Testnet)

- **Network Name**: Polygon Amoy Testnet
- **RPC URL**: `https://rpc-amoy.polygon.technology/`
- **Chain ID**: `80002`
- **Symbol**: `POL`
- **Explorer**: [PolygonScan Amoy](https://amoy.polygonscan.com/)

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
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## 📄 Documentation

For full product requirements, screen lists, and database schema, refer to the [Product Requirements Document (PRD)](./RemitFlow_PRD.md).

---

## 🏆 HackCraft 3.0 Hackathon Project
Built with ❤️ on Polygon.