# Bitchat-Flutter-Plugin

This is the Flutter plugin for the [bitchat](https://github.com/permissionlesstech/bitchat) core protocol and BLE mesh networking.

- Provides core decentralized chat protocol features
- Supports Bluetooth Low Energy (BLE) mesh networking for message relay
- Usable in both mobile and desktop Flutter projects

<img src="https://image.nostr.build/31625c86439eef530546b8a1cece959257aec5d5c67c95a0fc4f5871002c527f.jpg" alt="Bitchat Flutter Plugin Demo Screenshot" width="300" style="max-width: 100%; height: auto;">

## Usage

This plugin is designed for Flutter apps that need to integrate the bitchat protocol, peer-to-peer messaging, and Bluetooth relay features.

## Platform Support

- ✅ **iOS**: Fully supported with BLE peripheral and central functionality
- 🚧 **Android**: In development (BLE central functionality available, peripheral support coming soon)

## iOS Bluetooth Permissions

To use this plugin on iOS, you need to add the following permissions to your `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to discover and communicate with nearby devices for decentralized messaging.</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to discover and communicate with nearby devices for decentralized messaging.</string>
```

### Required Capabilities

Add the following capabilities to your iOS app in Xcode:

1. **Background Modes**:
   - `bluetooth-central` - For scanning and connecting to other devices
   - `bluetooth-peripheral` - For advertising and being discovered by other devices

2. **Bluetooth**:
   - Enable "Bluetooth" capability in your app's target settings

### iOS BLE Limitations

- iOS requires user permission for Bluetooth usage
- Background BLE operations are limited and may be suspended by the system
- Peripheral advertising may be restricted when the app is in background
- Maximum advertising data size is 28 bytes on iOS

## Installation

```yaml
dependencies:
  bitchat_flutter_plugin:
    git:
      url: https://github.com/wcat7/bitchat-flutter-plugin.git
      ref: master
```

## Quick Start

```dart
import 'package:bitchat_flutter_plugin/bitchat_core.dart';

// Initialize the service
final service = BitchatService();
await service.initialize();

// Start the service
await service.start(
  peerID: 'my-unique-peer-id',
  nickname: 'MyNickname',
);

// Send a private message
await service.sendPrivateMessage('recipient-id', 'Hello!');

// Send a channel message
await service.sendChannelMessage('#general', 'Hello everyone!');

// Listen for messages
service.messageStream.listen((message) {
  print('Received: ${message.content} from ${message.senderNickname}');
});
```

## API Documentation

### BitchatService

The main service class that coordinates all bitchat functionality.

#### Properties

- `status` - Current service status (stopped, initializing, running, error)
- `myPeerID` - Your unique peer identifier
- `myNickname` - Your display nickname
- `discoveredPeers` - List of discovered peers
- `discoveredChannels` - List of discovered channels

#### Streams

- `messageStream` - Stream of incoming messages
- `peerStream` - Stream of discovered peers
- `statusStream` - Stream of status changes
- `logStream` - Stream of log messages

#### Methods

```dart
// Initialize the service
Future<bool> initialize()

// Start the service with your peer ID
Future<bool> start({required String peerID, String? nickname})

// Stop the service
Future<void> stop()

// Send private message
Future<bool> sendPrivateMessage(String recipientID, String content)

// Send channel message
Future<bool> sendChannelMessage(String channel, String content)

// Get peer by ID
Peer? getPeer(String peerID)

// Get channel by name
Channel? getChannel(String channelName)
```

### BitchatMessage

Represents a message in the bitchat network.

#### Properties

- `id` - Unique message identifier
- `type` - Message type (see MessageTypes)
- `content` - Message content
- `senderID` - Sender's peer ID
- `senderNickname` - Sender's display name
- `recipientID` - Recipient ID (for private messages)
- `channel` - Channel name (for channel messages)
- `timestamp` - Message timestamp in milliseconds
- `isDelivered` - Whether message has been delivered
- `isRead` - Whether message has been read
- `isEncrypted` - Whether message is encrypted
- `signature` - Message signature for verification

#### Methods

```dart
// Check if this is a channel message
bool get isChannelMessage

// Check if this is a private message
bool get isPrivateMessage

// Check if this is a system message
bool get isSystemMessage

// Get message timestamp as DateTime
DateTime get dateTime

// Get formatted timestamp (e.g., "2h ago")
String get formattedTime
```

### Peer

Represents a discovered peer in the network.

#### Properties

- `id` - Peer's unique identifier
- `nickname` - Peer's display name
- `publicKey` - Peer's public key for encryption
- `lastSeen` - When peer was last seen
- `isOnline` - Whether peer is currently online

### Channel

Represents a chat channel.

#### Properties

- `name` - Channel name
- `description` - Channel description
- `memberCount` - Number of members
- `lastMessage` - Last message in channel
- `lastActivity` - Last activity timestamp

### Message Types

- `MessageTypes.private` - Private message between peers
- `MessageTypes.channel` - Public channel message
- `MessageTypes.announce` - Peer announcement
- `MessageTypes.keyExchange` - Encryption key exchange
- `MessageTypes.system` - System message

### Error Handling

The service throws `BitchatError` exceptions for various error conditions:

- `notInitialized` - Service not initialized
- `notRunning` - Service not running
- `encryptionFailed` - Message encryption failed
- `signatureFailed` - Message signature verification failed
- `decryptionFailed` - Message decryption failed
- `invalidPeer` - Invalid peer ID
- `messageTooLarge` - Message exceeds size limit
- `networkError` - Network communication error
- `permissionDenied` - Required permissions not granted
