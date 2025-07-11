import 'dart:async';
import 'package:bitchat_flutter_plugin/bitchat_flutter_plugin.dart';

/// Command Line Demo - Demonstrates how to use BitchatService in Dart code
/// 
/// This example shows:
/// 1. How to initialize the service
/// 2. How to start the service
/// 3. How to send different types of messages
/// 4. How to listen to events
/// 5. How to get service information
/// 6. How to stop the service
class CommandLineDemo {
  final BitchatService _service = BitchatService();
  final List<String> _logs = [];
  
  /// Run the demo
  Future<void> run() async {
    print('🚀 Starting Bitchat Command Line Demo...\n');
    
    // Set up event listeners
    _setupListeners();
    
    // Step 1: Initialize service
    await _initializeService();
    
    // Step 2: Start service
    await _startService();
    
    // Step 3: Demonstrate message sending
    await _demonstrateMessageSending();
    
    // Step 4: Show service information
    _showServiceInfo();
    
    // Step 5: Wait for network activity
    await _waitForNetworkActivity();
    
    // Step 6: Stop service
    await _stopService();
    
    print('\n✅ Demo completed successfully!');
  }
  
  /// Set up event listeners
  void _setupListeners() {
    // Listen to status changes
    _service.statusStream.listen((status) {
      _addLog('📊 Status changed to: ${status.name}');
    });
    
    // Listen to incoming messages
    _service.messageStream.listen((message) {
      _addLog('📨 Received: "${message.content}" from ${message.senderNickname}');
      _addLog('   Type: ${message.isPrivateMessage ? "Private" : "Broadcast"}');
      _addLog('   Time: ${message.formattedTime}');
    });
    
    // Listen to peer discoveries
    _service.peerStream.listen((peer) {
      _addLog('👤 Discovered peer: ${peer.nickname} (${peer.id})');
    });
    
    // Listen to logs
    _service.logStream.listen((log) {
      _addLog('📝 $log');
    });
  }
  
  /// Step 1: Initialize service
  Future<void> _initializeService() async {
    print('🔄 Step 1: Initializing service...');
    
    final success = await _service.initialize();
    
    if (success) {
      print('✅ Service initialized successfully');
    } else {
      print('❌ Service initialization failed');
      throw Exception('Failed to initialize service');
    }
    
    print('');
  }
  
  /// Step 2: Start service
  Future<void> _startService() async {
    print('🚀 Step 2: Starting service...');
    
    final peerId = 'demo-peer-${DateTime.now().millisecondsSinceEpoch}';
    final nickname = 'Demo User';
    
    print('   Peer ID: $peerId');
    print('   Nickname: $nickname');
    
    final success = await _service.start(
      peerID: peerId,
      nickname: nickname,
    );
    
    if (success) {
      print('✅ Service started successfully');
    } else {
      print('❌ Service start failed');
      throw Exception('Failed to start service');
    }
    
    print('');
  }
  
  /// Step 3: Demonstrate message sending
  Future<void> _demonstrateMessageSending() async {
    print('📤 Step 3: Demonstrating message sending...\n');
    
    // Wait for service to fully start
    await Future.delayed(Duration(seconds: 2));
    
    // Send broadcast message
    print('📢 Sending broadcast message...');
    final broadcastSuccess = await _service.sendBroadcastMessage('Hello everyone! This is a broadcast message.');
    print(broadcastSuccess ? '✅ Broadcast message sent' : '❌ Failed to send broadcast message');
    
    await Future.delayed(Duration(seconds: 1));
    
    // Send private message
    print('\n💬 Sending private message...');
    final privateSuccess = await _service.sendPrivateMessage(
      'example-peer-id',
      'Hello! This is a private message.'
    );
    print(privateSuccess ? '✅ Private message sent' : '❌ Failed to send private message');
    
    await Future.delayed(Duration(seconds: 1));
    
    // Send channel message
    print('\n📢 Sending channel message...');
    final channelSuccess = await _service.sendChannelMessage(
      'demo-channel',
      'Hello channel! This is a channel message.'
    );
    print(channelSuccess ? '✅ Channel message sent' : '❌ Failed to send channel message');
    
    print('');
  }
  
  /// Step 4: Show service information
  void _showServiceInfo() {
    print('ℹ️  Step 4: Service Information');
    print('   Status: ${_service.status.name}');
    print('   My Peer ID: ${_service.myPeerID ?? "Not set"}');
    print('   My Nickname: ${_service.myNickname ?? "Not set"}');
    print('   Discovered Peers: ${_service.discoveredPeers.length}');
    print('   Discovered Channels: ${_service.discoveredChannels.length}');
    
    // Show discovered peers
    if (_service.discoveredPeers.isNotEmpty) {
      print('\n   Discovered Peers:');
      for (final peer in _service.discoveredPeers) {
        print('     - ${peer.nickname} (${peer.id})');
      }
    }
    
    print('');
  }
  
  /// Step 5: Wait for network activity
  Future<void> _waitForNetworkActivity() async {
    print('⏳ Step 5: Waiting for network activity...');
    print('   (This will wait for 10 seconds to observe any incoming messages or peer discoveries)');
    print('   (You can run this demo on multiple devices to see network activity)');
    
    for (int i = 10; i > 0; i--) {
      print('   Waiting... $i seconds remaining');
      await Future.delayed(Duration(seconds: 1));
    }
    
    print('');
  }
  
  /// Step 6: Stop service
  Future<void> _stopService() async {
    print('🛑 Step 6: Stopping service...');
    
    await _service.stop();
    
    print('✅ Service stopped successfully');
    print('');
  }
  
  /// Add log
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    
    // Keep log count reasonable
    if (_logs.length > 100) {
      _logs.removeAt(0);
    }
  }
  
  /// Show recent logs
  void showRecentLogs() {
    print('\n📋 Recent Logs:');
    print('─' * 50);
    
    final recentLogs = _logs.takeLast(20).toList();
    for (final log in recentLogs) {
      print(log);
    }
    
    print('─' * 50);
  }
}

/// Main function - Run command line demo
void main() async {
  final demo = CommandLineDemo();
  
  try {
    await demo.run();
  } catch (e) {
    print('\n❌ Demo failed with error: $e');
  }
  
  // Show recent logs
  demo.showRecentLogs();
}

/// Simplified API usage example
class SimpleApiExample {
  final BitchatService _service = BitchatService();
  
  /// Quick start example
  Future<void> quickStart() async {
    print('🚀 Quick Start Example');
    
    // 1. Initialize
    await _service.initialize();
    
    // 2. Start
    await _service.start(
      peerID: 'quick-demo-${DateTime.now().millisecondsSinceEpoch}',
      nickname: 'Quick Demo',
    );
    
    // 3. Send message
    await _service.sendBroadcastMessage('Hello from quick start!');
    
    // 4. Listen to messages
    _service.messageStream.listen((message) {
      print('📨 Quick: ${message.content}');
    });
    
    // 5. Wait for a while
    await Future.delayed(Duration(seconds: 5));
    
    // 6. Stop
    await _service.stop();
    
    print('✅ Quick start completed');
  }
}

/// Error handling example
class ErrorHandlingExample {
  final BitchatService _service = BitchatService();
  
  /// Demonstrate error handling
  Future<void> demonstrateErrorHandling() async {
    print('🛡️  Error Handling Example');
    
    try {
      // Try to start service
      final success = await _service.initialize();
      if (!success) {
        print('❌ Initialization failed');
        return;
      }
      
      await _service.start(peerID: 'error-demo');
      
      // Try to send message
      await _service.sendBroadcastMessage('Test message');
      
    } catch (e) {
      print('❌ Error occurred: $e');
      
      // Handle specific error types
      if (e is BitchatError) {
        switch (e) {
          case BitchatError.permissionDenied:
            print('   → Bluetooth permissions not granted');
            break;
          case BitchatError.networkError:
            print('   → Network connection error');
            break;
          case BitchatError.notInitialized:
            print('   → Service not initialized');
            break;
          default:
            print('   → Unknown bitchat error');
        }
      }
    } finally {
      // Ensure cleanup
      await _service.stop();
    }
  }
} 