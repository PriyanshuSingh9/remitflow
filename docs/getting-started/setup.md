# Getting Started

Follow these instructions to set up the RemitFlow development environment.

## Prerequisites

- **Flutter SDK**: `^3.x`
- **Node.js**: `^20.x`
- **Foundry**: For smart contract development.
- **Neon Account**: For the serverless Postgres database.
- **Google Cloud Console**: For OAuth2 Client ID.

## 1. Smart Contracts Setup

```bash
cd smart_contracts
forge install
forge build
```
- Set up your `.env` in `smart_contracts/` with `POLYGON_AMOY_RPC_URL` and `PRIVATE_KEY`.
- Run tests: `forge test`.

## 2. Backend Setup

```bash
cd backend
npm install
```
- Configure `.env` (see Environment Variables section below).
- Initialize database:
```bash
npx prisma generate
npx prisma migrate dev --name init
```
- Start development server: `npm run dev`.

## 3. Mobile App Setup

```bash
cd mobile
flutter pub get
```
- Ensure you have a `.env` file in the root of the mobile folder if required.
- Run on emulator/device: `flutter run`.

## Environment Variables

### Backend (`backend/.env`)
```env
DATABASE_URL="postgresql://user:password@host/dbname?sslmode=require"
PORT=3000
GOOGLE_CLIENT_ID="your-google-client-id"
POLYGON_RPC_URL="https://rpc-amoy.polygon.technology/"
ESCROW_CONTRACT_ADDRESS="0x..."
OPERATOR_PRIVATE_KEY="0x..."
```

### Mobile (`mobile/.env`)
```env
API_BASE_URL="http://localhost:3000"
GOOGLE_CLIENT_ID="your-google-client-id"
POLYGON_RPC_URL="https://rpc-amoy.polygon.technology/"
ESCROW_CONTRACT_ADDRESS="0x..."
USDC_CONTRACT_ADDRESS="0x..."
```

## Troubleshooting
- **Database Connection**: Ensure the Neon database allows connections from your IP or uses the pooled connection string.
- **RPC Issues**: Use a reliable RPC provider like Alchemy or Infura if the public Amoy RPC is slow.
