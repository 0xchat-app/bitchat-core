# Bitchat-Core

A Flutter package for decentralized mesh networking over Bluetooth Low Energy (BLE).

## Features

- 🔐 **End-to-End Encryption**: X25519 key exchange, AES-256-GCM encryption, Ed25519 signatures
- 📡 **BLE Mesh Networking**: Advertise and scan for peers, relay messages through mesh network
- 💬 **Private Messaging**: Encrypted direct messages between peers
- 📢 **Channel Messaging**: Public channel messages with signature verification
- 🔄 **Store & Forward**: Message persistence and delivery when peers come online
- 🛡️ **Message Padding**: PKCS#7 padding for privacy protection
- ⚡ **Binary Protocol**: Efficient binary message format

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  bitchat_core:
    git:
      url: https://github.com/0xchat-app/bitchat-core.git
      ref: main
```

## Quick Start

```dart
import 'package:bitchat_core/bitchat_core.dart';

// Initialize the service
final bitchatService = BitchatService();
await bitchatService.initialize();

// Start the service
await bitchatService.start(
  peerID: 'my-unique-peer-id',
  nickname: 'MyNickname',
);

// Send a private message
await bitchatService.sendPrivateMessage('recipient-id', 'Hello!');

// Send a channel message
await bitchatService.sendChannelMessage('#general', 'Hello everyone!');

// Listen for messages
bitchatService.messageStream.listen((message) {
  print('Received: ${message.content} from ${message.senderNickname}');
});
```

## Architecture

### Core Components

- **BitchatService**: Main service interface
- **EncryptionService**: X25519/AES-256-GCM/Ed25519 cryptography
- **BluetoothMeshService**: BLE advertising and scanning
- **MessageRouter**: Message routing and delivery
- **StoreAndForward**: Message persistence and offline delivery

### Message Types

- **Private Messages**: End-to-end encrypted direct messages
- **Channel Messages**: Public messages with signature verification
- **Peer Discovery**: BLE advertisement packets
- **Key Exchange**: X25519 key exchange for encryption

### Security Features

- **X25519 Key Exchange**: Elliptic curve key agreement
- **AES-256-GCM Encryption**: Authenticated encryption
- **Ed25519 Signatures**: Digital signatures for message integrity
- **PKCS#7 Padding**: Message padding for privacy
- **HKDF Key Derivation**: Secure key derivation

## Compatibility

This package is designed to be compatible with the Swift bitchat implementation, supporting:

- Same encryption algorithms (X25519 + AES-256-GCM + Ed25519)
- Same message padding (PKCS#7)
- Same binary protocol format
- Same BLE advertisement format

## License

MIT License - see [LICENSE](LICENSE) file for details.
