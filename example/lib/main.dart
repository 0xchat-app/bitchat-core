import 'package:flutter/material.dart';
import 'package:bitchat_flutter_plugin/bitchat_flutter_plugin.dart';

void main() {
  runApp(const BitchatDemoApp());
}

class BitchatDemoApp extends StatelessWidget {
  const BitchatDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitchat-flutter-plugin Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BitchatDemoPage(),
    );
  }
}

class BitchatDemoPage extends StatefulWidget {
  const BitchatDemoPage({super.key});

  @override
  State<BitchatDemoPage> createState() => _BitchatDemoPageState();
}

class _BitchatDemoPageState extends State<BitchatDemoPage> {
  final BitchatService _bitchatService = BitchatService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _peerIdController = TextEditingController();
  final TextEditingController _channelController = TextEditingController();
  
  List<BitchatMessage> _messages = [];
  List<Peer> _peers = [];
  List<Channel> _channels = [];
  String _status = 'Stopped';
  String _myPeerId = '';
  String _myNickname = '';
  List<String> _logs = [];
  
  bool _isConnected = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupStreams();
    _initializeService();
  }

  void _setupStreams() {
    // Listen to status changes
    _bitchatService.statusStream.listen((status) {
      setState(() {
        _status = status.name;
      });
    });

    // Listen to incoming messages
    _bitchatService.messageStream.listen((message) {
      setState(() {
        _messages.add(message);
      });
      _showMessageNotification(message);
    });

    // Listen to peer discoveries
    _bitchatService.peerStream.listen((peer) {
      setState(() {
        if (!_peers.any((p) => p.id == peer.id)) {
          _peers.add(peer);
        }
      });
    });

    // Listen to logs
    _bitchatService.logStream.listen((log) {
      setState(() {
        _logs.add(log);
        if (_logs.length > 100) {
          _logs.removeAt(0);
        }
      });
    });
  }

  Future<void> _initializeService() async {
    setState(() {
      _status = 'Initializing...';
    });

    final success = await _bitchatService.initialize();
    setState(() {
      _isInitialized = success;
      _status = success ? 'Initialized' : 'Initialization Failed';
    });

    if (success) {
      _addLog('✅ Service initialized successfully');
    } else {
      _addLog('❌ Service initialization failed');
    }
  }

  Future<void> _startService() async {
    if (_myPeerId.isEmpty) {
      _showSnackBar('Please enter a Peer ID');
      return;
    }

    setState(() {
      _status = 'Starting...';
    });

    final success = await _bitchatService.start(
      peerID: _myPeerId,
      nickname: _myNickname.isNotEmpty ? _myNickname : null,
    );

    setState(() {
      _isConnected = success;
      _status = success ? 'Running' : 'Start Failed';
    });

    if (success) {
      _addLog('✅ Service started successfully');
      _showSnackBar('Service started successfully');
    } else {
      _addLog('❌ Service start failed');
      _showSnackBar('Failed to start service');
    }
  }

  Future<void> _stopService() async {
    await _bitchatService.stop();
    setState(() {
      _isConnected = false;
      _status = 'Stopped';
    });
    _addLog('🛑 Service stopped');
  }

  Future<void> _sendBroadcastMessage() async {
    if (_messageController.text.isEmpty) {
      _showSnackBar('Please enter a message');
      return;
    }

    final success = await _bitchatService.sendBroadcastMessage(_messageController.text);
    if (success) {
      _addLog('📢 Broadcast message sent: ${_messageController.text}');
      _messageController.clear();
    } else {
      _addLog('❌ Failed to send broadcast message');
    }
  }

  Future<void> _sendPrivateMessage() async {
    if (_peerIdController.text.isEmpty) {
      _showSnackBar('Please enter a Peer ID');
      return;
    }
    if (_messageController.text.isEmpty) {
      _showSnackBar('Please enter a message');
      return;
    }

    final success = await _bitchatService.sendPrivateMessage(
      _peerIdController.text,
      _messageController.text,
    );
    
    if (success) {
      _addLog('💬 Private message sent to ${_peerIdController.text}: ${_messageController.text}');
      _messageController.clear();
    } else {
      _addLog('❌ Failed to send private message');
    }
  }

  Future<void> _sendChannelMessage() async {
    if (_channelController.text.isEmpty) {
      _showSnackBar('Please enter a channel name');
      return;
    }
    if (_messageController.text.isEmpty) {
      _showSnackBar('Please enter a message');
      return;
    }

    final success = await _bitchatService.sendChannelMessage(
      _channelController.text,
      _messageController.text,
    );
    
    if (success) {
      _addLog('📢 Channel message sent to ${_channelController.text}: ${_messageController.text}');
      _messageController.clear();
    } else {
      _addLog('❌ Failed to send channel message');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showMessageNotification(BitchatMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New message from ${message.senderNickname}: ${message.content}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitchat-flutter-plugin Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status and Connection Section
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
                    Text('My Peer ID: ${_bitchatService.myPeerID ?? "Not set"}'),
                    Text('My Nickname: ${_bitchatService.myNickname ?? "Not set"}'),
                    Text('Discovered Peers: ${_bitchatService.discoveredPeers.length}'),
                    Text('Discovered Channels: ${_bitchatService.discoveredChannels.length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Connection Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Peer ID',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _myPeerId = value,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Nickname (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _myNickname = value,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnected ? null : _startService,
                            child: const Text('Start Service'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnected ? _stopService : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Stop Service'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Message Sending Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Send Messages',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // Broadcast Message
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isConnected ? _sendBroadcastMessage : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Send Broadcast Message'),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Private Message
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _peerIdController,
                            decoration: const InputDecoration(
                              labelText: 'Peer ID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnected ? _sendPrivateMessage : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Send Private'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Channel Message
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _channelController,
                            decoration: const InputDecoration(
                              labelText: 'Channel',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnected ? _sendChannelMessage : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Send to Channel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Messages Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Received Messages',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('(${_messages.length})'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
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
            
            // Peers Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discovered Peers (${_peers.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: _peers.length,
                        itemBuilder: (context, index) {
                          final peer = _peers[index];
                          return ListTile(
                            title: Text(peer.nickname),
                            subtitle: Text(peer.id),
                            leading: const Icon(Icons.person),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Logs',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text('(${_logs.length})'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              _logs[_logs.length - 1 - index],
                              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
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
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _peerIdController.dispose();
    _channelController.dispose();
    super.dispose();
  }
} 