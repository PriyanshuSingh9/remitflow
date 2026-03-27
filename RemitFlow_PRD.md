# RemitFlow — Product Requirements Document
> Version 1.0 | Cross-Border Remittance on Shardeum | HackCraft 3.0

## 1. Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Mobile App | Flutter (Dart) 
| Blockchain | Shardeum Sphinx Testnet | EVM-compatible, near-zero gas |
| Smart Contract | Solidity 
| Wallet Abstraction | Firebase Auth + Deterministic Local Key | Google login, HMAC-SHA256 local key, no seed phrases |
| Blockchain SDK | web3dart (Flutter package) | Talks to Shardeum RPC |
| On-Ramp | Transak API | USD → USDC via WebView widget |
| Off-Ramp | OnMeta API | USDC → INR to bank/UPI |
| DEX / Liquidity | Shardeum native AMM DEX | No own liquidity pool — use DEX |
| Database | Firebase Firestore | Transaction history, user profiles |

---

## 3. Transfer Flow (Step by Step)

```
Step 1 — User A opens app, enters amount ($1000) and receiver details
Step 2 — App shows live preview: USDC equivalent, INR receiver gets, fee breakdown
Step 3 — User A confirms → Transak WebView opens inside app
Step 4 — Transak converts USD → USDC, deposits to User A's deterministic local wallet on Shardeum
Step 5 — RemitFlow smart contract receives USDC from User A wallet
Step 6 — Smart contract routes USDC through Shardeum DEX to User B wallet
Step 7 — OnMeta detects USDC in User B wallet, converts USDC → INR
Step 8 — INR credited to User B's bank account or UPI (instant via UPI)
Step 9 — Both users get push notification. Tx hash visible on Shardeum Explorer.
```

---

## 4. Smart Contract Specification

### What It Does
- Receives USDC from sender's local wallet
- Routes through Shardeum DEX AMM
- Transfers USDC to receiver's wallet
- Emits a `Transfer` event (sender, receiver, amount, timestamp)
- Reverts if sender balance is insufficient
- Non-custodial: never holds funds beyond execution

### Deployment
- Written in Solidity 0.8.x
- Deployed via Foundry (Forge)
- Network: Shardeum Sphinx Testnet
- Foundry uses Shardeum RPC for deployment scripts and verification
- ABI and contract address stored in Firestore or accessed locally, referenced in Flutter app

### Events to Emit
```
event Transfer(
    address indexed sender,
    address indexed receiver,
    uint256 usdcAmount,
    uint256 timestamp
);
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
- On success: App generates a deterministic Shardeum wallet privately and seamlessly using HMAC-SHA256 from the Firebase UID
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
  - Shardeum gas: <$0.01
  - Off-ramp fee: X%
  - Total fee: $X
  - Receiver gets: ₹XX,XXX
  - Estimated time: 5–10 minutes
- Confirm & Send button

### Screen 6: On-Ramp WebView (Transak)
- Opens as a bottom sheet or full screen
- Embeds Transak widget via `webview_flutter`
- Pre-filled: USD amount, USDC as target crypto, Shardeum network, User A wallet address
- On completion: WebView dismisses, app moves to Transfer Progress screen

### Screen 7: Transfer Progress
- Real-time status tracker with 4 steps:
  1. On-Ramp — USDC purchased (check mark when Transak confirms)
  2. On-Chain Settlement — smart contract routing (check mark when tx confirmed on Shardeum)
  3. Off-Ramp — INR conversion in progress (check mark when OnMeta confirms)
  4. Credited — INR in User B's account
- Show Shardeum Explorer link as soon as tx hash is available
- Estimated time countdown

### Screen 8: Transaction Detail
- Full transfer summary:
  - USD sent
  - USDC settled
  - INR received
  - Total fees
  - Timestamp
  - Status badge
  - "View on Shardeum Explorer" button (opens tx hash URL)

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
  - `network`: `shardeum`
  - `cryptoCurrencyCode`: `USDC`
  - `walletAddress`: User A's derived local wallet address
  - `fiatAmount`: amount user entered
  - `fiatCurrency`: `USD`
- Listen for Transak's `TRANSAK_ORDER_SUCCESSFUL` event via JavaScript bridge
- On success: close WebView, proceed to transfer progress screen

### 6.2 OnMeta (Off-Ramp)
- Integration: REST API called from Flutter/backend when smart contract Transfer event fires
- Trigger: listen for Transfer event on Shardeum using `web3dart` event subscription
- API call: POST to OnMeta off-ramp endpoint with:
  - USDC amount received
  - User B's bank account or UPI handle
  - Target currency: INR
- OnMeta handles conversion and bank credit
- Use OnMeta sandbox for hackathon demo

### 6.3 Firebase Auth + Local Deterministic Wallet
- Package: `firebase_auth`, `google_sign_in`, `crypto`, `flutter_secure_storage`
- Init with Firebase Google Sign-In config.
- After login: Firebase provides a `uid`. The app hashes this `uid` with HMAC-SHA256 to generate a 256-bit wallet private key.
- Private key is stored securely in `flutter_secure_storage`.
- The derived EVM wallet address and user profile metadata are pushed to Firestore `users` collection.
- Use the local private key directly to sign transactions via `web3dart`.

---

## 7. Firestore Database Schema

### Collection: `users`
**Document ID:** `uid` (Firebase UID)
```json
{
  "email": "user@gmail.com",
  "name": "Jane Doe",
  "photoUrl": "https://...",
  "walletAddress": "0xABC123...",
  "country": "IN",
  "bank_details": "{... encrypted JSON ...}",
  "createdAt": "2026-03-27T10:00:00Z",
  "lastLogin": "timestamp"
}
```

### Collection: `transactions`
**Document ID:** auto-generated
```json
{
  "sender_id": "uidA",
  "receiver_id": "uidB",
  "amount_usd": 1000.00,
  "amount_usdc": 995.50,
  "amount_inr": 82000.00,
  "fee_usd": 4.50,
  "tx_hash": "0x444...",
  "status": "pending", // pending | on_chain | off_ramp | completed | failed
  "created_at": "timestamp",
  "completed_at": "timestamp"
}
```

---

## 8. Shardeum Configuration

### RPC Details (Sphinx Testnet)
```
Network Name:   Shardeum Sphinx
RPC URL:        https://sphinx.shardeum.org/
Chain ID:       8082
Symbol:         USDC
Explorer:       https://explorer-sphinx.shardeum.org/
```

### web3dart Connection
- Connect Flutter app to Shardeum RPC using `Web3Client`
- Use user's locally derived private key to safely sign EVM transactions locally
- Subscribe to Transfer events from the smart contract address

---

## 9. Firebase Cloud Messaging (Notifications)

### Notification Triggers
| Event | Who gets notified | Message |
|---|---|---|
| On-ramp complete | Sender | "USDC purchased. Transfer in progress." |
| On-chain confirmed | Sender | "Transfer confirmed on Shardeum. Tx: 0x..." |
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
7. Open Shardeum Explorer on browser — show the actual on-chain transaction
8. Show User B's wallet balance updated in the app
9. INR off-ramp: show OnMeta sandbox confirmation (or mock screen)
10. Both users receive push notifications

### What is Real vs Mocked
| Step | Status |
|---|---|
| Google login + Native deterministic wallet | Real |
| Transak on-ramp widget | Real (testnet) |
| USDC on Shardeum testnet | Real — verifiable on Explorer |
| Smart contract routing | Real — verifiable on Explorer |
| User B wallet balance update | Real on-chain |
| INR off-ramp via OnMeta | Sandbox / mocked for demo |
| Push notifications | Real via FCM |

---

## 11. Build Sequence

Build in this exact order to avoid blockers:

1. **Smart Contract** — Write and deploy on Shardeum Sphinx via Foundry. Get ABI + address.
2. **Flutter Init** — Create Flutter project. Add all dependencies to `pubspec.yaml`.
3. **Firebase Auth & Wallet** — Integrate Google Sign In & HMAC-SHA256 deterministic key generation. Store secure keys and push user to Firestore.
4. **web3dart** — Connect to Shardeum RPC. Read generated wallet USDC balance. Call contract.
5. **Transak WebView** — Embed widget. Test USD → USDC on testnet.
6. **OnMeta** — Integrate off-ramp API. Test in sandbox.
7. **Firestore Database** — Store and sync transaction history.
8. **All Screens** — Build UI in order from Section 5.
9. **FCM Notifications** — Add Firebase Messaging, wire up triggers.
10. **End-to-End Test** — Full flow on Shardeum testnet. Confirm Explorer shows tx.

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
  url_launcher: latest      # Shardeum Explorer links
```

---

## 13. Environment Variables

Store all secrets in a `.env` file (never commit to git):

```
SHARDEUM_RPC_URL=https://sphinx.shardeum.org/
SHARDEUM_CHAIN_ID=8082
CONTRACT_ADDRESS=<deployed contract address from Forge>
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

- **Shardeum only** — no other blockchain. All on-chain activity on Shardeum Sphinx Testnet.
- **No own liquidity pool** — route through Shardeum DEX. RemitFlow holds zero USDC.
- **Foundry for Smart Contracts** — No Remix IDE or Hardhat.
- **Firebase Auth & Firestore** — Used for all backend, authentication, and database actions.
- **Firebase + Deterministic Wallet** — Used instead of MetaMask or any external Web3-focused providers to retain full seamless abstraction.
- **Flutter only** — no Next.js or web frontend.