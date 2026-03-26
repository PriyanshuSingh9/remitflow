# RemitFlow — Product Requirements Document
> Version 1.0 | Cross-Border Remittance on Shardeum | HackCraft 3.0

## 1. Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Mobile App | Flutter (Dart) 
| Blockchain | Shardeum Sphinx Testnet | EVM-compatible, near-zero gas |
| Smart Contract | Solidity 
| Wallet Abstraction | Web3Auth Flutter SDK | Email/Google login, no seed phrases |
| Blockchain SDK | web3dart (Flutter package) | Talks to Shardeum RPC |
| On-Ramp | Transak API | USD → USDC via WebView widget |
| Off-Ramp | OnMeta API | USDC → INR to bank/UPI |
| DEX / Liquidity | Shardeum native AMM DEX | No own liquidity pool — use DEX |
| Database | Neon (Serverless Postgres) | Transaction history, user profiles |

---

## 3. Transfer Flow (Step by Step)

```
Step 1 — User A opens app, enters amount ($1000) and receiver details
Step 2 — App shows live preview: USDC equivalent, INR receiver gets, fee breakdown
Step 3 — User A confirms → Transak WebView opens inside app
Step 4 — Transak converts USD → USDC, deposits to User A's Web3Auth wallet on Shardeum
Step 5 — RemitFlow smart contract receives USDC from User A wallet
Step 6 — Smart contract routes USDC through Shardeum DEX to User B wallet
Step 7 — OnMeta detects USDC in User B wallet, converts USDC → INR
Step 8 — INR credited to User B's bank account or UPI (instant via UPI)
Step 9 — Both users get push notification. Tx hash visible on Shardeum Explorer.
```

---

## 4. Smart Contract Specification

### What It Does
- Receives USDC from sender's Web3Auth wallet
- Routes through Shardeum DEX AMM
- Transfers USDC to receiver's Web3Auth wallet
- Emits a `Transfer` event (sender, receiver, amount, timestamp)
- Reverts if sender balance is insufficient
- Non-custodial: never holds funds beyond execution

### Deployment
- Written in Solidity 0.8.x
- Deployed via Foundry (Forge)
- Network: Shardeum Sphinx Testnet
- Foundry uses Shardeum RPC for deployment scripts and verification
- ABI and contract address stored in Neon DB, referenced in Flutter app

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
- Web3Auth Flutter SDK integration
- Options: Continue with Google, Continue with Email
- On success: Web3Auth generates a Shardeum wallet address silently
- No seed phrases, no MetaMask, no crypto jargon

### Screen 3: KYC / Bank Linking
- Country selector (determines currency and off-ramp)
- Bank account number + IFSC (India) or routing number (USA)
- UPI handle input (India receivers)
- All stored encrypted in Neon DB

### Screen 4: Home Dashboard
- Top: User's display name + country flag
- Middle: "Send Money" primary button (large, prominent)
- Below: Live USDC/USD and USDC/INR exchange rate ticker
- Bottom: Recent transactions list (last 5)

### Screen 5: Send Money
- Recipient search: by email or phone number (looks up Neon DB)
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
  - `walletAddress`: User A's Web3Auth wallet address
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

### 6.3 Web3Auth
- Package: `web3auth_flutter`
- Init with Shardeum chain config (chain ID, RPC URL)
- Login methods: Google, Email passwordless
- After login: retrieve the user's Shardeum wallet address and private key (stored securely in device)
- Use the private key to sign transactions via `web3dart`

---

## 7. Neon Database Schema

### Table: users
```
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
email           TEXT NOT NULL UNIQUE
wallet_address  TEXT NOT NULL UNIQUE  -- Shardeum address from Web3Auth
country         TEXT NOT NULL         -- 'IN' or 'US' etc
bank_details    TEXT                  -- encrypted JSON: account no, IFSC or UPI
created_at      TIMESTAMPTZ DEFAULT now()
```

### Table: transactions
```
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
sender_id       UUID REFERENCES users(id)
receiver_id     UUID REFERENCES users(id)
amount_usd      NUMERIC(12,2)         -- USD amount User A sent
amount_usdc     NUMERIC(18,8)         -- USDC amount on-chain
amount_inr      NUMERIC(12,2)         -- INR amount User B received
fee_usd         NUMERIC(8,2)          -- total fee in USD
tx_hash         TEXT                  -- Shardeum on-chain tx hash
status          TEXT DEFAULT 'pending' -- pending | on_chain | off_ramp | completed | failed
created_at      TIMESTAMPTZ DEFAULT now()
completed_at    TIMESTAMPTZ
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
- Use user's Web3Auth private key to sign transactions
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
- Store FCM token in Neon users table
- Trigger notifications from server-side when smart contract events fire

---

## 10. Hackathon Demo Flow

What to show judges (in order):

1. Open RemitFlow app on Android device
2. Log in with Google → Web3Auth creates wallet silently
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
| Google login via Web3Auth | Real |
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
3. **Web3Auth** — Integrate login. Confirm wallet address is generated on login.
4. **web3dart** — Connect to Shardeum RPC. Read wallet USDC balance. Call contract.
5. **Transak WebView** — Embed widget. Test USD → USDC on testnet.
6. **OnMeta** — Integrate off-ramp API. Test in sandbox.
7. **Neon DB** — Set up schema. Wire up user creation and transaction logging.
8. **All Screens** — Build UI in order from Section 5.
9. **FCM Notifications** — Add Firebase, wire up triggers.
10. **End-to-End Test** — Full flow on Shardeum testnet. Confirm Explorer shows tx.

---

## 12. Flutter Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  web3auth_flutter: latest
  web3dart: latest
  webview_flutter: latest
  firebase_core: latest
  firebase_messaging: latest
  http: latest
  postgres: latest          # Neon connection
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
WEB3AUTH_CLIENT_ID=<your Web3Auth client ID>
NEON_DATABASE_URL=<your Neon connection string>
FIREBASE_PROJECT_ID=<your Firebase project ID>
```

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
- **No Supabase** — Neon for database.
- **No MetaMask for users** — Web3Auth only. Fully abstracted.
- **Flutter only** — no Next.js or web frontend.