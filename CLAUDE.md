# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter Android application that integrates with MetaMask wallet using WalletConnect protocol. The app allows users to:
- Connect to MetaMask wallet
- View wallet balance
- Sign messages
- Send ETH transactions

## Architecture

### Core Components

- `lib/services/wallet_service.dart`: Singleton service handling WalletConnect integration and MetaMask communication
- `lib/screens/wallet_screen.dart`: Main UI screen with wallet connection status, balance display, message signing, and transaction sending
- `lib/main.dart`: App entry point with WalletService initialization

### Key Dependencies

- `walletconnect_flutter_v2`: WalletConnect protocol implementation (Note: deprecated, should migrate to reown_appkit)
- `url_launcher`: Opens MetaMask app or fallback to browser
- `http`: JSON-RPC calls for blockchain interactions

## Development Commands

### Build and Run
```bash
flutter run                    # Run in debug mode
flutter build apk --debug      # Build debug APK
flutter build apk --release    # Build release APK
```

### Code Quality
```bash
flutter analyze                # Static code analysis
flutter test                   # Run tests
flutter pub outdated           # Check for dependency updates
```

### Dependency Management
```bash
flutter pub get                # Install dependencies
flutter pub upgrade            # Upgrade dependencies
```

## Configuration Requirements

### WalletConnect Setup
1. Get a project ID from [WalletConnect Cloud](https://cloud.walletconnect.com/)
2. Replace `'YOUR_PROJECT_ID'` in `wallet_service.dart:28`

### Blockchain RPC Setup
1. Get an API key from [Alchemy](https://dashboard.alchemy.com/)
2. Replace `'YOUR_ALCHEMY_KEY'` in `wallet_service.dart:139`

### Android Permissions
The app requires these permissions (already configured in AndroidManifest.xml):
- `INTERNET`: Network access for blockchain calls
- `ACCESS_NETWORK_STATE`: Network state monitoring

## Key Implementation Details

### Wallet Connection Flow
1. User taps "MetaMask 연결" button
2. App creates WalletConnect session URI
3. App attempts to open MetaMask app with `metamask://wc?uri=` scheme
4. Falls back to browser if MetaMask app not installed
5. User approves connection in MetaMask
6. Session established, account address retrieved

### Transaction Signing
- Uses `personal_sign` method for message signing
- Uses `eth_sendTransaction` for ETH transfers
- All operations require active WalletConnect session

### State Management
- Uses Flutter's StatefulWidget for UI state
- WalletService maintains connection state as singleton
- Real-time balance updates after transactions

## Known Issues & Limitations

1. **Deprecated Dependency**: `walletconnect_flutter_v2` is deprecated. Should migrate to `reown_appkit`
2. **Hardcoded Chain**: Currently only supports Ethereum mainnet (chain ID: eip155:1)
3. **Basic Error Handling**: Limited user feedback for connection failures
4. **No Offline Support**: Requires internet connection for all operations

## Testing

### Manual Testing Steps
1. Install MetaMask mobile app
2. Build and install APK on Android device
3. Test wallet connection flow
4. Test message signing with short text
5. Test ETH transaction (use testnet for safety)

### Debugging
- Check Flutter logs: `flutter logs`
- Monitor WalletConnect events in wallet_service.dart
- Use Android Studio's device log for native issues

## Security Considerations

- Never commit API keys or private keys
- Always validate user inputs before blockchain calls  
- Use testnet for development and testing
- Implement proper error handling to prevent information disclosure