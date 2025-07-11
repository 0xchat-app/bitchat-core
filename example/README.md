# Bitchat Flutter Plugin Demo

This is a demo application demonstrating how to use the Bitchat Flutter Plugin.

![Bitchat Flutter Plugin Demo Screenshot](https://image.nostr.build/31625c86439eef530546b8a1cece959257aec5d5c67c95a0fc4f5871002c527f.jpg)

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

### iOS Permissions

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect with nearby devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to connect with nearby devices</string>
```