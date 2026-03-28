# RemitFlow — Product Requirements Document
> Version 1.1 | Cross-Border Remittance on Polygon | HackCraft 3.0

## 1. Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Mobile App | Flutter (Dart) | User-facing interface |
| Blockchain | Polygon Amoy Testnet | EVM-compatible, near-zero gas |
| Smart Contract | RemitFlowEscrow (Solidity) | Locks USDC until off-ramp completes |
| Wallet Abstraction | Google OAuth + HMAC Key | No seed phrases, deterministic local wallet |
| Blockchain SDK | web3dart (Flutter) / ethers.js (Backend) | Cross-chain and RPC interactions |
| On-Ramp | Transak API | USD → USDC via WebView widget |
| Off-Ramp | OnMeta API | USDC → INR via bank/UPI |
| Database | Neon (PostgreSQL) + Prisma | Transaction history, user profiles |
| Backend API | Express.js (Node.js) | Manages escrow, DB sync, Google Auth verification |

---

## 3. Transfer Flow (Step by Step)

```
Step 1 — User A opens app, enters amount ($1000) and receiver details
Step 2 — App shows live preview: USDC equivalent, INR receiver gets, fee breakdown
Step 3 — User A confirms → Transak WebView opens inside app
Step 4 — Transak converts USD → USDC, deposits to User A's deterministic local wallet on Polygon
Step 5 — RemitFlow smart contract receives USDC from User A wallet
Step 6 — Sender or Operator deposits USDC to RemitFlowEscrow smart contract
Step 7 — Backend listens (using ethers.js) and triggers OnMeta off-ramp initialization
Step 8 — OnMeta confirms off-ramp readiness, backend releases escrow to off-ramp wallet
Step 9 — INR credited to User B's bank account or UPI (instant via UPI)
Step 10 — Both users get push notification. Tx hash visible on Polygon Scan Explorer.
```

---

## 4. Smart Contract Specification

### What It Does
- Conditional escrow for cross-border remittances
- Receives USDC from sender's local wallet or via operator
- Escrows funds until backend confirms off-ramp readiness
- Releases funds to off-ramp provider when ready
- Refunds funds to sender if off-ramp times out (24 hours) or fails
- Emits `EscrowDeposited`, `EscrowReadyForFunding`, `EscrowReleased`, and `EscrowRefunded` events

### Deployment
- Written in Solidity 0.8.x
- Deployed via Foundry (Forge)
- Network: Polygon Amoy Testnet
- Foundry uses Polygon RPC for deployment scripts and verification
- ABI and contract address stored in backend or accessed locally, referenced in Flutter app

### Events to Emit
```solidity
event EscrowDeposited(uint256 indexed escrowId, address indexed sender, address indexed receiver, uint256 amount, uint256 timestamp);
event EscrowReadyForFunding(uint256 indexed escrowId, uint256 timestamp);
event EscrowReleased(uint256 indexed escrowId, address indexed receiver, uint256 amount, uint256 timestamp);
event EscrowRefunded(uint256 indexed escrowId, address indexed sender, uint256 amount, uint256 timestamp);
```

---

## 5. Flutter App — Screen List

Build the following screens in order:

### Screen 1: Splash / Onboarding
- App logo centered
- Tagline: "Send money home. Fast. Fair. Borderless."
- Single CTA button: "Get Started"

### Screen 2: Login
- Google Sign-In using `google_sign_in` linked with Firebase Auth
- On success: App generates a deterministic Polygon wallet privately and seamlessly using HMAC-SHA256 from the Firebase UID
- Wallet address synced to Firestore, encrypted private key saved sequentially in `flutter_secure_storage`
- No seed phrases, no MetaMask, no crypto jargon

### Screen 3: KYC / Bank Linking
- Country selector (determines currency and off-ramp)
- Bank account number + IFSC (India) or routing number (USA)
- UPI handle input (India receivers)
- All stored securely in Firestore user document

### Screen 4: Home Dashboard
- Top: User's display name + country flag
- Middle: "Send Money" primary button (large, prominent)
- Below: Live USDC/USD and USDC/INR exchange rate ticker
- Bottom: Recent transactions list (last 5)

### Screen 5: Send Money
- Recipient search: by email or phone number (looks up Firestore database)
- Amount input: USD field (auto-converts and shows INR equivalent live)
- Fee breakdown card:
  - On-ramp fee: X%
  - Polygon gas: <$0.01
  - Off-ramp fee: X%
  - Total fee: $X
  - Receiver gets: ₹XX,XXX
  - Estimated time: 5–10 minutes
- Confirm & Send button

### Screen 6: On-Ramp WebView (Transak)
- Opens as a bottom sheet or full screen
- Embeds Transak widget via `webview_flutter`
- Pre-filled: USD amount, USDC as target crypto, Polygon network, User A wallet address
- On completion: WebView dismisses, app moves to Transfer Progress screen

### Screen 7: Transfer Progress
- Real-time status tracker with 4 steps:
  1. On-Ramp — USDC purchased (check mark when Transak confirms)
  2. On-Chain Settlement — smart contract routing (check mark when tx confirmed on Polygon)
  3. Off-Ramp — INR conversion in progress (check mark when OnMeta confirms)
  4. Credited — INR in User B's account
- Show PolygonScan Explorer link as soon as tx hash is available
- Estimated time countdown

### Screen 8: Transaction Detail
- Full transfer summary:
  - USD sent
  - USDC settled
  - INR received
  - Total fees
  - Timestamp
  - Status badge
  - "View on PolygonScan" button (opens tx hash URL)

### Screen 9: Transaction History
- Scrollable list of all transfers
- Each row: receiver name, amount, date, status badge (Completed / Pending / Failed)
- Tap to open Transaction Detail

### Screen 10: Receive Money
- User's shareable payment link
- QR code encoding the user's wallet address and app deep link
- "Share" button

### Screen 11: Profile / Settings
- Display linked bank / UPI details
- Edit bank details
- Notification preferences toggle
- Log out

---

## 6. API Integration Details

### 6.1 Transak (On-Ramp)
- Integration: `webview_flutter` package embeds the Transak hosted widget
- Config params to pass:
  - `apiKey`: your Transak API key
  - `network`: `polygon`
  - `cryptoCurrencyCode`: `USDC`
  - `walletAddress`: User A's derived local wallet address
  - `fiatAmount`: amount user entered
  - `fiatCurrency`: `USD`
- Listen for Transak's `TRANSAK_ORDER_SUCCESSFUL` event via JavaScript bridge
- On success: close WebView, proceed to transfer progress screen

### 6.2 OnMeta (Off-Ramp)
- Integration: REST API called from Express backend when smart contract `EscrowDeposited` event fires
- Trigger: Backend listens for events on Polygon Amoy testnet using `ethers.js`
- API call: POST to OnMeta off-ramp endpoint with:
  - USDC amount received
  - User B's bank account or UPI handle
  - Target currency: INR
- OnMeta handles conversion and bank credit
- Use OnMeta sandbox for hackathon demo

### 6.3 Google OAuth + Local Deterministic Wallet
- Package: `google_sign_in`, `crypto`, `flutter_secure_storage`, `google-auth-library` in backend
- Init with Google Sign-In config.
- After login: App receives an ID token. The app hashes the Google `uid` with HMAC-SHA256 to generate a 256-bit wallet private key.
- Private key is stored securely in `flutter_secure_storage`.
- The derived EVM wallet address and user profile are pushed to the Neon database via the Express backend using JWT auth.
- Use the local private key directly to sign transactions locally before broadcasting.

---

## 7. Neon (PostgreSQL) Database Schema

Defined via Prisma (`schema.prisma`):

### Model: `User` (table: `users`)
- `id`: UUID (Primary Key)
- `googleSubject`: String (Unique)
- `email`: String (Unique)
- `displayName`: String
- `photoUrl`: String
- `walletAddress`: String (Unique)
- `country`: String (default: "US")
- `bankDetails`: String

### Model: `Transaction` (table: `transactions`)
- `id`: UUID (Primary Key)
- `senderId`, `receiverId`: UUID (Relations to `User`)
- `amountUsd`, `amountUsdc`, `amountInr`, `feeUsd`: Decimal
- `txHash`, `escrowTxHash`, `releaseTxHash`: String
- `escrowId`: Int
- `status`: Enum (`pending | escrow_locked | offramp_pending | offramp_ready | escrow_released | completed | failed | refunded`)

### Model: `RampOrder` (table: `ramp_orders`)
- `id`: UUID (Primary Key)
- `type`: String (`onramp` | `offramp`)
- `transactionId`: UUID (Relation to `Transaction`)
- `externalOrderId`: String (Unique)
- `status`: String

---

## 8. Polygon Configuration

### RPC Details (Amoy Testnet)
```
Network Name:   Polygon Amoy Testnet
RPC URL:        https://rpc-amoy.polygon.technology/
Chain ID:       80002
Symbol:         POL
Explorer:       https://amoy.polygonscan.com/
```

### web3dart Connection
- Connect Flutter app to Polygon RPC using `Web3Client`
- Use user's locally derived private key to safely sign EVM transactions locally
- Subscribe to Transfer events from the smart contract address

---

## 9. Firebase Cloud Messaging (Notifications)

### Notification Triggers
| Event | Who gets notified | Message |
|---|---|---|
| On-ramp complete | Sender | "USDC purchased. Transfer in progress." |
| On-chain confirmed | Sender | "Transfer confirmed on Polygon. Tx: 0x..." |
| Off-ramp complete | Receiver | "You received ₹XX,XXX from [Sender Name]" |
| Transfer failed | Sender | "Transfer failed. Funds returned to your wallet." |

### Setup
- Add `firebase_messaging` Flutter package
- Store FCM token in Firestore `users` document
- Trigger notifications when Firestore `transactions` status is updated via Cloud Functions or server-side listener

---

## 10. Hackathon Demo Flow

What to show judges (in order):

1. Open RemitFlow app on Android device
2. Log in with Google → Custom Auth generates EVM wallet silently on local device
3. Go to Send Money → enter $1000, select receiver
4. Show live fee breakdown and INR preview
5. Confirm → Transak widget opens → complete test purchase on testnet
6. Show Transfer Progress screen updating in real-time
7. Open PolygonScan Amoy Explorer on browser — show the actual on-chain transaction
8. Show User B's wallet balance updated in the app
9. INR off-ramp: show OnMeta sandbox confirmation (or mock screen)
10. Both users receive push notifications

### What is Real vs Mocked
| Step | Status |
|---|---|
| Google login + Native deterministic wallet | Real |
| Transak on-ramp widget | Real (testnet) |
| USDC on Polygon Amoy testnet | Real — verifiable on PolygonScan |
| Smart contract routing | Real — verifiable on PolygonScan |
| User B wallet balance update | Real on-chain |
| INR off-ramp via OnMeta | Sandbox / mocked for demo |
| Push notifications | Real via FCM |

---

## 11. Build Sequence

Build in this exact order to avoid blockers:

1. **Smart Contract** — Write Escrow logic and deploy on Polygon Amoy via Foundry. Get ABI + address.
2. **Flutter & Express Init** — Create Flutter and Backend projects. Add dependencies.
3. **Google Auth & Wallet** — Integrate Google Sign In & HMAC-SHA256 deterministic key generation. Store secure keys and push user to Postgres.
4. **web3dart & ethers.js** — Connect to Polygon RPC. Set up backend ethers listener. Read generated wallet USDC balance. Call Escrow contract.
5. **Transak WebView** — Embed widget. Test USD → USDC on testnet.
6. **OnMeta** — Integrate off-ramp API triggered by backend on Escrow deposit. Test in sandbox.
7. **Neon Database** — Store and sync transaction history using Prisma.
8. **All Screens** — Build UI in order from Section 5.
9. **FCM Notifications** — Add Firebase Messaging, wire up triggers from backend.
10. **End-to-End Test** — Full conditional flow on Polygon Amoy testnet. Confirm PolygonScan shows escrow deposit and release.

---

## 12. Flutter Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_sign_in: latest
  firebase_core: latest
  firebase_auth: latest
  cloud_firestore: latest
  flutter_secure_storage: latest
  crypto: latest
  web3dart: latest
  webview_flutter: latest
  firebase_messaging: latest
  http: latest
  flutter_dotenv: latest    # API keys from .env
  qr_flutter: latest        # QR code for receive screen
  url_launcher: latest      # PolygonScan Explorer links
```

---

## 13. Environment Variables

Store all secrets in a `.env` file (never commit to git):

```
POLYGON_RPC_URL=https://rpc-amoy.polygon.technology/
POLYGON_CHAIN_ID=80002
CONTRACT_ADDRESS=0x3a0937C9B8eecad82549369187EF1f96BD9B6c23
CONTRACT_ABI=<ABI JSON string>
TRANSAK_API_KEY=<your Transak API key>
ONMETA_API_KEY=<your OnMeta API key>
```
*(Firebase configuration handles itself through google-services.json natively)*

---

## 14. Out of Scope (Do Not Build for Hackathon)

- Full KYC / AML compliance pipeline
- RBI / FinCEN regulatory licensing
- Production off-ramp for all currency corridors
- iOS App Store submission
- USDC price volatility hedging
- Customer support system
- Multi-currency beyond USD → INR

---

## 15. Key Constraints

- **Polygon only** — no other blockchain. All on-chain activity on Polygon Amoy Testnet.
- **No own liquidity pool** — route through Polygon DEX (QuickSwap). RemitFlow holds zero USDC.
- **Foundry for Smart Contracts** — No Remix IDE or Hardhat.
- **Node.js, Express & Neon PostgreSQL** — Used for all backend, authentication (Google OAuth2 + JWT), and database actions (Prisma).
- **Google OAuth + Deterministic Wallet** — Used instead of MetaMask or any external Web3-focused providers to retain full seamless abstraction.
- **Flutter only** — no Next.js or web frontend.