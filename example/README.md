# Bitchat Flutter Plugin Demo

This is a complete demo application demonstrating how to use the Bitchat Flutter Plugin.

## 📱 Features

### 1. Service Management
- ✅ Initialize BitchatService
- ✅ Start/Stop service
- ✅ Real-time status monitoring
- ✅ Permission management

### 2. Messaging Features
- ✅ Broadcast message sending
- ✅ Private message sending
- ✅ Channel message sending
- ✅ Message receiving monitoring

### 3. Network Features
- ✅ Peer discovery
- ✅ Channel discovery
- ✅ Real-time connection status

### 4. Monitoring Features
- ✅ Real-time log display
- ✅ Message history
- ✅ Peer list display

## 🚀 Quick Start

### 1. Run Demo Application

```bash
# Enter example directory
cd example

# Get dependencies
flutter pub get

# Run application
flutter run
```

### 2. Usage Steps

1. **Start Service**
   - Enter your Peer ID (required)
   - Enter nickname (optional)
   - Click "Start Service" button

2. **Send Messages**
   - **Broadcast Message**: Enter content in message box, click "Send Broadcast Message"
   - **Private Message**: Enter target Peer ID and message content, click "Send Private"
   - **Channel Message**: Enter channel name and message content, click "Send to Channel"

3. **Monitor Status**
   - View service status and connection information
   - Observe discovered peer list
   - View received messages
   - Monitor real-time logs

## 📚 API Usage Examples

### Basic Setup

```dart
import 'package:bitchat_flutter_plugin/bitchat_flutter_plugin.dart';

final BitchatService bitchatService = BitchatService();
```

### Service Lifecycle

```dart
// Initialize service
await bitchatService.initialize();

// Start service
await bitchatService.start(
  peerID: 'your-peer-id',
  nickname: 'Your Nickname',
);

// Stop service
await bitchatService.stop();
```

### Message Sending

```dart
// Send broadcast message
await bitchatService.sendBroadcastMessage('Hello everyone!');

// Send private message
await bitchatService.sendPrivateMessage('peer-id', 'Hello!');

// Send channel message
await bitchatService.sendChannelMessage('channel-name', 'Hello channel!');
```

### Event Listening

```dart
// Listen to status changes
bitchatService.statusStream.listen((status) {
  print('Status: ${status.name}');
});

// Listen to received messages
bitchatService.messageStream.listen((message) {
  print('Received: ${message.content} from ${message.senderNickname}');
});

// Listen to discovered peers
bitchatService.peerStream.listen((peer) {
  print('Discovered: ${peer.nickname} (${peer.id})');
});

// Listen to logs
bitchatService.logStream.listen((log) {
  print('Log: $log');
});
```

### Get Service Information

```dart
// Get current status
BitchatStatus status = bitchatService.status;

// Get my information
String? myPeerID = bitchatService.myPeerID;
String? myNickname = bitchatService.myNickname;

// Get discovered peers and channels
List<Peer> peers = bitchatService.discoveredPeers;
List<Channel> channels = bitchatService.discoveredChannels;
```

## 🔧 Configuration Requirements

### Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect with nearby devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect with nearby devices</string>
```

## 📋 File Structure

```
example/
├── lib/
│   ├── main.dart                 # Main application entry
│   ├── simple_api_demo.dart      # Simple API demo
│   └── command_line_demo.dart    # Command line demo
├── pubspec.yaml                  # Dependency configuration
└── README.md                     # Documentation
```

## 🎯 Testing Recommendations

### Single Device Testing
1. Start the application
2. Observe service status changes
3. Send broadcast messages
4. View log output

### Multi-Device Testing
1. Run the application on multiple devices
2. Ensure devices are within Bluetooth range
3. Observe peer discovery
4. Test message sending and receiving

### Network Testing
1. Test broadcast message propagation
2. Test private messages
3. Test channel messages
4. Observe message latency and reliability

## 🐛 Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure Bluetooth permissions are granted in app settings
   - Reinstall the application

2. **Service Start Failed**
   - Check if device Bluetooth is enabled
   - Check if permissions are correctly granted
   - View logs for detailed error information

3. **Message Sending Failed**
   - Ensure service status is "running"
   - Check network connection
   - View logs for error details

4. **Peer Discovery Failed**
   - Ensure devices are within Bluetooth range
   - Check if Bluetooth scanning is working properly
   - Wait for scanning to complete

### Debugging Tips

```dart
// Enable detailed logging
bitchatService.logStream.listen((log) {
  print('🔍 [Bitchat] $log');
});

// Monitor service status
bitchatService.statusStream.listen((status) {
  print('📊 [Status] ${status.name}');
});

// Check service state
print('Service running: ${bitchatService.status == BitchatStatus.running}');
print('My peer ID: ${bitchatService.myPeerID}');
print('Discovered peers: ${bitchatService.discoveredPeers.length}');
```

## 📖 More Documentation

- [API Usage Examples](../API_USAGE_EXAMPLES.md) - Detailed API usage guide
- [Main Project README](../README.md) - Plugin main project description
- [pubspec.yaml](../pubspec.yaml) - Plugin configuration information

## 🤝 Contributing

If you find any issues or have improvement suggestions, please:

1. Check existing Issues
2. Create a new Issue describing the problem
3. Submit a Pull Request to fix the issue

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details. 