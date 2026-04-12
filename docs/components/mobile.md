# Mobile Application

The RemitFlow mobile app is built with **Flutter**, providing a cross-platform experience for sending and receiving money.

## Key Features

### 1. Deterministic Wallet Generation
Instead of traditional seed phrases, RemitFlow uses the user's Google UID to derive a deterministic EVM wallet:
- **Algorithm**: HMAC-SHA256.
- **Security**: The private key is stored exclusively in the device's Secure Storage (`flutter_secure_storage`) and is never sent to the backend.
- **Result**: Users have a consistent wallet address across devices by simply logging in with Google.

### 2. On-Ramp Integration (Transak)
- A `webview_flutter` widget embeds the Transak SDK.
- The app pre-fills the amount, destination wallet, and currency to minimize user error.
- Listens for `TRANSAK_ORDER_SUCCESSFUL` events to advance the UI.

### 3. Real-Time Transaction Tracking
- A dedicated "Transfer Progress" screen provides live updates on the 4-step lifecycle:
    1. On-Ramp (Fiat to USDC)
    2. On-Chain (USDC to Escrow)
    3. Off-Ramp (USDC to Fiat)
    4. Credited (Bank/UPI receipt)

### 4. Interactive UI
- **Live Rates**: Dynamic exchange rate ticker using `provider` or `bloc` for state management.
- **Fee Transparency**: Detailed breakdown of on-ramp, gas, and off-ramp fees before confirmation.

## Technical Architecture

- **State Management**: Provider / Clean Architecture.
- **Blockchain**: `web3dart` for local transaction signing and RPC calls.
- **Local Storage**: `flutter_secure_storage` for sensitive keys.
- **Network**: `http` and `dio` for REST API communication.

## Development

### Prerequisites
- Flutter SDK `^3.22.0`
- Android Studio / Xcode

### Commands
```bash
cd mobile
flutter pub get
flutter run
```

## Folder Structure
- `lib/screens`: UI Layer.
- `lib/services`: API Clients and Blockchain interaction logic.
- `lib/models`: Data structures reflecting the backend Prisma schema.
- `lib/theme`: Standardized styling for the RemitFlow brand.
