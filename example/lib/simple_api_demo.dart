import 'package:flutter/material.dart';
import 'package:bitchat_flutter_plugin/bitchat_flutter_plugin.dart';

/// Simple API Demo - Demonstrates how to use BitchatService core APIs
class SimpleApiDemo extends StatefulWidget {
  const SimpleApiDemo({super.key});

  @override
  State<SimpleApiDemo> createState() => _SimpleApiDemoState();
}

class _SimpleApiDemoState extends State<SimpleApiDemo> {
  final BitchatService _service = BitchatService();
  final TextEditingController _messageController = TextEditingController();
  
  String _status = 'Not Started';
  List<String> _logs = [];
  List<BitchatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to status changes
    _service.statusStream.listen((status) {
      setState(() {
        _status = status.name;
      });
    });

    // Listen to incoming messages
    _service.messageStream.listen((message) {
      setState(() {
        _messages.add(message);
      });
      _addLog('📨 Received: ${message.content} from ${message.senderNickname}');
    });

    // Listen to logs
    _service.logStream.listen((log) {
      _addLog(log);
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
  }

  // Example 1: Initialize the service
  Future<void> _initializeService() async {
    _addLog('🔄 Initializing service...');
    final success = await _service.initialize();
    if (success) {
      _addLog('✅ Service initialized successfully');
    } else {
      _addLog('❌ Service initialization failed');
    }
  }

  // Example 2: Start the service with a peer ID
  Future<void> _startService() async {
    _addLog('🚀 Starting service...');
    final success = await _service.start(
      peerID: 'demo-peer-${DateTime.now().millisecondsSinceEpoch}',
      nickname: 'Demo User',
    );
    if (success) {
      _addLog('✅ Service started successfully');
    } else {
      _addLog('❌ Service start failed');
    }
  }

  // Example 3: Send a broadcast message
  Future<void> _sendBroadcastMessage() async {
    if (_messageController.text.isEmpty) {
      _addLog('⚠️ Please enter a message');
      return;
    }

    _addLog('📢 Sending broadcast message...');
    final success = await _service.sendBroadcastMessage(_messageController.text);
    if (success) {
      _addLog('✅ Broadcast message sent: ${_messageController.text}');
      _messageController.clear();
    } else {
      _addLog('❌ Failed to send broadcast message');
    }
  }

  // Example 4: Send a private message
  Future<void> _sendPrivateMessage() async {
    if (_messageController.text.isEmpty) {
      _addLog('⚠️ Please enter a message');
      return;
    }

    // Example peer ID - in real app, you'd get this from discovered peers
    const targetPeerId = 'example-peer-id';
    
    _addLog('💬 Sending private message to $targetPeerId...');
    final success = await _service.sendPrivateMessage(targetPeerId, _messageController.text);
    if (success) {
      _addLog('✅ Private message sent to $targetPeerId: ${_messageController.text}');
      _messageController.clear();
    } else {
      _addLog('❌ Failed to send private message');
    }
  }

  // Example 5: Send a channel message
  Future<void> _sendChannelMessage() async {
    if (_messageController.text.isEmpty) {
      _addLog('⚠️ Please enter a message');
      return;
    }

    const channelName = 'demo-channel';
    
    _addLog('📢 Sending channel message to $channelName...');
    final success = await _service.sendChannelMessage(channelName, _messageController.text);
    if (success) {
      _addLog('✅ Channel message sent to $channelName: ${_messageController.text}');
      _messageController.clear();
    } else {
      _addLog('❌ Failed to send channel message');
    }
  }

  // Example 6: Stop the service
  Future<void> _stopService() async {
    _addLog('🛑 Stopping service...');
    await _service.stop();
    _addLog('✅ Service stopped');
  }

  // Example 7: Get service information
  void _showServiceInfo() {
    final info = '''
Service Information:
- Status: ${_service.status}
- My Peer ID: ${_service.myPeerID ?? 'Not set'}
- My Nickname: ${_service.myNickname ?? 'Not set'}
- Discovered Peers: ${_service.discoveredPeers.length}
- Discovered Channels: ${_service.discoveredChannels.length}
- Received Messages: ${_messages.length}
''';
    _addLog('ℹ️ $info');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple API Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Messages: ${_messages.length}'),
                    Text('Logs: ${_logs.length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // API Examples
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Service Management
                    _buildApiSection(
                      'Service Management',
                      [
                        _buildApiButton('Initialize Service', _initializeService, Colors.blue),
                        _buildApiButton('Start Service', _startService, Colors.green),
                        _buildApiButton('Stop Service', _stopService, Colors.red),
                        _buildApiButton('Show Service Info', _showServiceInfo, Colors.orange),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Message Sending
                    _buildApiSection(
                      'Message Sending',
                      [
                        _buildApiButton('Send Broadcast', _sendBroadcastMessage, Colors.purple),
                        _buildApiButton('Send Private', _sendPrivateMessage, Colors.teal),
                        _buildApiButton('Send Channel', _sendChannelMessage, Colors.indigo),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Message Input
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Message Input',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: 'Enter message',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Messages List
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Received Messages (${_messages.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 150,
                              child: ListView.builder(
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[_messages.length - 1 - index];
                                  return ListTile(
                                    title: Text(message.senderNickname),
                                    subtitle: Text(message.content),
                                    trailing: Text(message.formattedTime),
                                                                leading: Icon(
                              message.isPrivateMessage ? Icons.person : Icons.radio,
                              color: message.isPrivateMessage ? Colors.green : Colors.blue,
                            ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Logs
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Logs (${_logs.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                itemCount: _logs.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1.0),
                                    child: Text(
                                      _logs[_logs.length - 1 - index],
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSection(String title, List<Widget> buttons) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...buttons,
          ],
        ),
      ),
    );
  }

  Widget _buildApiButton(String text, VoidCallback onPressed, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(text),
        ),
      ),
    );
  }
} 