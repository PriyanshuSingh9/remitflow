# RemitFlow — Mainnet Product Requirements Document (PRD)

> **Version 2.0 | Mainnet Deployment | Cross-Border Remittance on Polygon**

---

## 1. Product Vision & Value Proposition

### The Problem
Traditional cross-border banking rails (like PayPal, Wise, and SWIFT) are fundamentally slow, typically taking **3 to 5 business days** to process international currency transfers. To bypass these slow rails, some modern fiat remittance services use pre-funded liquidity pools in various countries. However, holding multiple fiat currencies in different jurisdictions introduces severe scalability bottlenecks and heavy regulatory/compliance burdens.

### The RemitFlow Solution
Instead of providing liquidity by holding different fiat currencies globally, RemitFlow leverages **blockchain infrastructure and cryptocurrencies** as the underlying liquidity layer. By using stablecoins (USDC) to bridge the currency gap, we settle transactions in seconds without needing fragmented regional fiat reserves.

We build on the **Polygon Blockchain** because of its incredibly fast block finality times and negligible gas fees, ensuring the remittance is both instant and highly cost-effective compared to traditional banking fees.

### Market Context (The India Corridors)
Web3 and crypto terminology carry a strong taboo in countries like India, where users are accustomed to the extreme simplicity of native payment systems like UPI (Unified Payments Interface). Therefore, **all blockchain complexity must be completely abstracted away.** The user experiences a standard Web2 fintech app, while Web3 powers the backend settlement.

---

## 2. Tech Stack & Integration Partners

| Layer | Technology | Purpose |
|---|---|---|
| **Blockchain** | Polygon PoS (Mainnet) | High speed, low gas, EMV-compatible settlement layer. |
| **Smart Contract** | RemitFlow Escrow | Locks USDC on-chain to ensure atomic swaps/settlement. |
| **On-Ramp & KYC** | Transak API | Converts USD to USDC natively within the app. Handles US KYC. |
| **Off-Ramp** | OnMeta API | Converts USDC to INR and settles to receivers' bank/UPI. Handles India KYC. |
| **Database** | Neon (PostgreSQL) | Stores real-world user profiles, transaction states, and fiat metadata. |
| **Wallet Layer** | Custom HMAC-SHA256 | Deterministic, keyless wallet generation hidden from users. |

---

## 3. Wallet Abstraction & Security Architecture

To accommodate users accustomed to simple flows (like UPI) and to avoid Web3 friction (seed phrases, gas tokens, wallet extensions), RemitFlow utilizes a **hidden, abstracted custody wallet approach**.

### Wallet Generation Flow:
1. **Google Authentication:** The user signs in using a native Google Sign-In pop-up.
2. **Unique Identifier:** Google provides a unique user identifier (`UID`).
3. **Key Derivation:** We combine the Google `UID` with a secure, app-level **salt phrase**.
4. **Hashing:** An `HMAC-SHA256` algorithm is used on the salted ID to deterministically generate a 256-bit Private Key.
5. **Secure Storage:** The Private Key is securely encrypted and stored entirely in the Android local hashed/secure storage (Android Keystore / `flutter_secure_storage`).
6. **Public Address:** A public EVM wallet address is derived from this local private key.
7. **Database Sync:** After successful login and wallet generation, user metadata and the public wallet address are fetched from/synced to the **Neon DB** for UI display.

**Result:** The user maintains a **keyless, abstracted custody wallet** where they never see a private key or mnemonic. Custody is managed transparently by the application.

---

## 4. End-to-End Transaction Flow (Mainnet)

RemitFlow uses a Smart Contract Escrow approach to guarantee funds are secure during the on-ramp to off-ramp transition. 

**Scenario:** User A (USA, holds USD) sends money to User B (India, requires INR).

### Step 1: User Initiation
User A initiates a transfer of dollars (USD) to User B through the RemitFlow app.

### Step 2: Pre-Settlement Verification (OnMeta)
*Crucial Step:* Before initiating any fiat conversion or charging fees, the app hits the **OnMeta pre-validation endpoint** to verify the receiver's banking/UPI details are active and valid. If validation fails here, the transaction is halted immediately, saving the user from paying on-ramp fees for a doomed transaction.

### Step 3: On-Ramp Activation (Transak)
Once receiver details are confirmed, the intent is finalized and the **Transak On-Ramp API** triggers. User A completes KYC (if required). Transak deducts the USD and deposits the minted USDC.

### Step 4: Smart Contract Trigger (Escrow)
To avoid forcing the user to hold MATIC for gas and sign complex multi-step transactions, the app utilizes an **`operatorDeposit()` pattern**. The backend operator handles the transaction and gas fees, depositing the USDC into the Escrow contract on behalf of the user. *(Phase 2 Path: Migrate this to a full EIP-4337 Account Abstraction or gasless relay for direct-from-wallet execution).*

### Step 5: Final Settlement or Revert
- **Success Case:** The off-ramp executes normally since receiver validation already passed in Step 2. The backend triggers the Escrow Contract to **release the USDC** to OnMeta's liquidity pools. OnMeta then immediately executes the INR payout to User B's bank/UPI.
- **Extreme Failure Case:** If the off-ramp unexpectedly fails after passing pre-validation, the Escrow Contract safely **reverts the USDC back to User A's wallet**. Because we pre-validated, this should be extremely rare, significantly reducing the chances of stranded funds that require a secondary off-ramp step to recover.

---

## 5. KYC & Regulatory Flow 

Because RemitFlow integrates directly with licensed fiat ramps, the regulatory burden of KYC (Know Your Customer) and AML (Anti-Money Laundering) is delegated to our API partners.

1. **Sender KYC (USA):** Handled by **Transak** during the on-ramp flow. Transak collects ID, SSN/Address, and funding source compliance.
2. **Receiver KYC (India):** Handled by **OnMeta** prior to the first off-ramp payout. Receivers may need to verify their PAN/Aadhaar depending on the volume thresholds.
3. **Non-Custodial Nature:** Because RemitFlow never holds user fiat directly and users hold their crypto via abstracted deterministic wallets, RemitFlow functions as a software interface rather than a licensed money transmitter.

---

## 6. App Infrastructure & UI Flow

### Backend System
- **Database (Neon PostgreSQL):** Manages user profiles (Display Name, Email, Bank/UPI details) and transaction statuses (`Pending_OnRamp`, `Escrowed`, `Validating_Receiver`, `Completed`, `Reverted`).
- **Indexers & Event Webhooks:** Instead of simple RPC block polling (which is vulnerable to reorgs and disconnects), mainnet events are tracked using production-grade infrastructure like **Alchemy Webhooks**, **The Graph**, or **Moralis Streams**. This provides guaranteed delivery for USDC deposits and Escrow state changes to reliably trigger callbacks.

### User Interface (Flutter)
- **Login:** Simple "Google Sign-In". No Web3 jargon.
- **Home:** Fetches Neon DB user data. Shows USD balance (abstracted from USDC) and transaction history.
- **Transfer:** Simple "Send To" interface using phone numbers/emails mapped to receiver UPI handles in Neon DB.
- **Fee Transparency:** Before initiating a transfer, the app explicitly shows the true fee breakdown to ensure regulatory compliance and trust:
  - On-ramp fee: ~1.5% (Transak, card) / ~0.5% (bank)
  - Gas: <$0.01 (Polygon)
  - Off-ramp fee: ~1.5% (OnMeta)
  - Total app fee: ~$X
  - Exchange rate locked at: 1 USDC = ₹XX.XX
  - **Recipient receives: ₹XX,XXX**
- **Status Tracker:** A visual progress bar updating in real time: `Verifying Receiver` -> `Converting USD` -> `Securing Funds` -> `Delivering INR`.

---

## 7. Mainnet Summary

1. **Chain:** Polygon PoS Mainnet (`Chain ID: 137`)
2. **Token:** Bridged USDC (`0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`) or Native USDC (`0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`) — pending final verification against OnMeta/Transak documentation matching.
3. **Contracts:** RemitFlow Escrow (Verified on PolygonScan)
4. **Fiat Ramps:** Transak (Production API), OnMeta (Production API)
5. **Wallet:** Proprietary HMAC-SHA256 Google UID derivation (Keyless Abstracted Custody).
