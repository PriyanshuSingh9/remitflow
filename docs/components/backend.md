# Backend Service

The RemitFlow backend is a Node.js application built with Express and Prisma, serving as the bridge between the mobile app, the database, and the Polygon blockchain.

## Technology Stack

- **Runtime**: Node.js (v20+)
- **Framework**: Express.js
- **Database**: Neon (PostgreSQL)
- **ORM**: Prisma
- **Blockchain Interaction**: ethers.js (v6)
- **Authentication**: Google Auth Library & JWT

## Database Schema (Prisma)

The system uses three primary models to track users, exchange rates, and transactions.

### 1. User (`users`)
- Stores user profiles, Google authentication IDs (`googleSubject`), and their derived `walletAddress`.
- Tracks `availableBalanceUsd` and `lifetimeSavingsUsd`.

### 2. Transaction (`transactions`)
- The core model for the remittance lifecycle.
- Relationships: `sender` and `receiver` (User).
- Fields: `amountUsd`, `amountUsdc`, `amountInr`, `feeUsd`.
- Blockchain Metadata: `txHash`, `escrowTxHash`, `releaseTxHash`, `escrowId`.
- **Status**: Tracks progress from `pending` to `completed`, `failed`, or `refunded`.

### 3. RampOrder (`ramp_orders`)
- Tracks external orders from Transak (on-ramp) and OnMeta (off-ramp).
- Linked to a specific `Transaction`.

## Key Services

### Blockchain Listener
The backend runs a listener using `ethers.js` to monitor the `RemitFlowEscrow` contract for `EscrowDeposited` events. When a deposit is detected:
1. The transaction status is updated to `escrow_locked`.
2. The off-ramp process is initiated via the OnMeta API.

### Authentication
- Users log in via Google on the mobile app.
- The app sends an ID token to the backend.
- The backend verifies the token using `google-auth-library` and issues a local JWT for session management.

## API Endpoints (Summary)

- `POST /auth/google`: Verify Google ID token and create/update user.
- `GET /users/me`: Retrieve current user profile and balance.
- `POST /transactions`: Initiate a new remittance transaction.
- `GET /transactions/:id`: Get real-time status of a transfer.
- `GET /rates`: Fetch live exchange rates (USDC/USD, USDC/INR).

## Running the Backend

```bash
cd backend
npm install
npx prisma generate
npm run dev
```
