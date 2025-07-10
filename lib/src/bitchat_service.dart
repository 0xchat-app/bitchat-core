/// Main bitchat service that coordinates all bitchat functionality
/// 
/// This is the primary interface for bitchat operations including
/// Bluetooth mesh networking, message routing, and encryption.
import 'dart:async';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'dart:convert'; // Added for jsonEncode

import 'protocol/binary_protocol.dart';
import 'protocol/bitchat_packet.dart';
import 'protocol/message_types.dart';
import 'bluetooth/bluetooth_mesh_service.dart';
import 'encryption/encryption_service.dart';
import 'messaging/message_router.dart';
import 'messaging/store_and_forward.dart';
import 'models/peer.dart';
import 'models/channel.dart';
import 'models/message.dart';
import 'utils/message_padding.dart';

/// Bitchat service errors
enum BitchatError implements Exception {
  notInitialized,
  notRunning,
  encryptionFailed,
  signatureFailed,
  decryptionFailed,
  invalidPeer,
  messageTooLarge,
  networkError,
  permissionDenied,
}

/// Bitchat service status
enum BitchatStatus {
  stopped,
  initializing,
  running,
  error,
}

/// Main bitchat service class
class BitchatService {
  static final BitchatService _instance = BitchatService._internal();
  factory BitchatService() => _instance;
  BitchatService._internal();

  final Logger _logger = Logger();
  
  // Core services
  late BluetoothMeshService _bluetoothService;
  late EncryptionService _encryptionService;
  late MessageRouter _messageRouter;
  late StoreAndForward _storeAndForward;
  
  // State
  BitchatStatus _status = BitchatStatus.stopped;
  String? _myPeerID;
  String? _myNickname;
  final List<Peer> _discoveredPeers = [];
  final List<Channel> _discoveredChannels = [];
  
  // Stream controllers
  final StreamController<BitchatMessage> _messageController = StreamController<BitchatMessage>.broadcast();
  final StreamController<Peer> _peerController = StreamController<Peer>.broadcast();
  final StreamController<BitchatStatus> _statusController = StreamController<BitchatStatus>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();
  
  /// Get current status
  BitchatStatus get status => _status;
  
  /// Get my peer ID
  String? get myPeerID => _myPeerID;
  
  /// Get my nickname
  String? get myNickname => _myNickname;
  
  /// Get discovered peers
  List<Peer> get discoveredPeers => List.unmodifiable(_discoveredPeers);
  
  /// Get discovered channels
  List<Channel> get discoveredChannels => List.unmodifiable(_discoveredChannels);
  
  /// Message stream
  Stream<BitchatMessage> get messageStream => _messageController.stream;
  
  /// Peer discovery stream
  Stream<Peer> get peerStream => _peerController.stream;
  
  /// Status change stream
  Stream<BitchatStatus> get statusStream => _statusController.stream;
  
  /// Log stream
  Stream<String> get logStream => _logController.stream;
  
  /// Initialize the bitchat service
  Future<bool> initialize() async {
    if (_status == BitchatStatus.initializing || _status == BitchatStatus.running) {
      return true;
    }
    
    try {
      _updateStatus(BitchatStatus.initializing);
      _log('Initializing bitchat service...');
      
      // Request permissions with detailed logging
      _log('Requesting Bluetooth permissions...');
      final bluetoothStatus = await Permission.bluetooth.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      
      _log('Bluetooth permission status: $bluetoothStatus');
      _log('Bluetooth scan permission status: $bluetoothScanStatus');
      _log('Bluetooth connect permission status: $bluetoothConnectStatus');
      
      if (bluetoothStatus != PermissionStatus.granted ||
          bluetoothScanStatus != PermissionStatus.granted ||
          bluetoothConnectStatus != PermissionStatus.granted) {
        _log('Bluetooth permissions not granted - continuing for testing');
        // Continue for testing purposes
      }
      
      // Initialize services
      _encryptionService = EncryptionService();
      _bluetoothService = BluetoothMeshService();
      _messageRouter = MessageRouter();
      _storeAndForward = StoreAndForward();
      
      // Set up message router callbacks
      _messageRouter.setMessageCallback(_handleIncomingMessage);
      _messageRouter.setKeyExchangeCallback(_handleKeyExchange);
      
      // Set up store and forward callbacks
      _storeAndForward.setMessageStoredCallback(_handleMessageStored);
      _storeAndForward.setMessageDeliveredCallback(_handleMessageDelivered);
      _storeAndForward.setPeerOnlineCallback(_handlePeerOnline);
      
      // Set up BLE service callbacks
      await _bluetoothService.startScanning(
        onPeer: (peerId, publicKeyDigest) {
          _handlePeerDiscovered(peerId, publicKeyDigest);
        },
      );
      
      // Set up message received callback for BLE
      _bluetoothService.setMessageReceivedCallback((senderId, data) {
        _handleIncomingBleMessage(senderId, data);
      });
      
      _updateStatus(BitchatStatus.stopped);
      _log('Bitchat service initialized successfully');
      return true;
    } catch (e) {
      _log('Failed to initialize bitchat service: $e');
      _updateStatus(BitchatStatus.error);
      return false;
    }
  }
  
  /// Start the bitchat service
  Future<bool> start({required String peerID, String? nickname}) async {
    if (_status == BitchatStatus.running) return true;
    
    if (_status == BitchatStatus.stopped) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    if (peerID.isEmpty) {
      _log('Invalid peer ID');
      return false;
    }
    
    try {
      _updateStatus(BitchatStatus.initializing);
      _log('Starting bitchat service...');
      
      _myPeerID = peerID;
      _myNickname = nickname ?? 'User${peerID.substring(0, 4)}';
      
      // Generate key pair for this session
      final keyPair = await _encryptionService.generateKeyPair();
      _encryptionService.loadKeyPair(keyPair);
      
      // Get public key data for advertising
      final publicKeyData = await _encryptionService.getCombinedPublicKeyData();
      if (publicKeyData == null) {
        _log('Failed to generate public key data');
        return false;
      }
      
      // Start BLE advertising (with error handling)
      try {
        await _bluetoothService.startAdvertising(
          peerId: peerID,
          nickname: _myNickname!,
          publicKeyDigest: publicKeyData,
        );
        _log('BLE advertising started successfully');
      } catch (e) {
        _log('BLE advertising failed: $e');
      }
      
      // Start message router
      try {
        await _messageRouter.start();
        _log('Message router started successfully');
      } catch (e) {
        _log('Message router failed to start: $e');
      }
      
      // Start store and forward
      try {
        await _storeAndForward.start();
        _log('Store and forward started successfully');
      } catch (e) {
        _log('Store and forward failed to start: $e');
      }
      
      _updateStatus(BitchatStatus.running);
      _log('Bitchat service started successfully');
      
      // Send initial announce message to broadcast our presence
      try {
        await sendAnnounceMessage();
        _log('Sent initial announce message');
      } catch (e) {
        _log('Failed to send initial announce message: $e');
      }
      
      // Start periodic announce messages
      startPeriodicAnnounce();
      
      return true;
    } catch (e) {
      _log('Failed to start bitchat service: $e');
      _updateStatus(BitchatStatus.error);
      return false;
    }
  }
  
  /// Stop the bitchat service
  Future<void> stop() async {
    if (_status == BitchatStatus.stopped) return;
    
    try {
      _log('Stopping bitchat service...');
      
      await _bluetoothService.stopAdvertising();
      await _bluetoothService.stopScanning();
      await _messageRouter.stop();
      await _storeAndForward.stop();
      
      _updateStatus(BitchatStatus.stopped);
      _log('Bitchat service stopped');
    } catch (e) {
      _log('Error stopping bitchat service: $e');
      _updateStatus(BitchatStatus.error);
    }
  }
  
  /// Send a private message
  Future<bool> sendPrivateMessage(String recipientID, String content) async {
    if (_status != BitchatStatus.running) {
      _log('Service not running, cannot send message');
      return false;
    }
    
    if (recipientID.isEmpty) {
      _log('Invalid recipient ID');
      return false;
    }
    
    if (content.isEmpty) {
      _log('Message content cannot be empty');
      return false;
    }
    
    // Check if we have encryption keys for this peer
    if (!_encryptionService.hasSharedSecret(recipientID)) {
      _log('No encryption keys for peer $recipientID, initiating key exchange');
      // Initiate key exchange first
      await _initiateKeyExchange(recipientID);
    }
    
    try {
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.message,  // Use unified message type like Swift
        recipientID: recipientID,
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: _myPeerID!,
        senderNickname: _myNickname!,
      );
      
      return await _sendMessage(message);
    } catch (e) {
      _log('Failed to send private message: $e');
      return false;
    }
  }
  
  /// Send a channel message
  Future<bool> sendChannelMessage(String channel, String content) async {
    if (_status != BitchatStatus.running) return false;
    
    if (channel.isEmpty) {
      _log('Channel name cannot be empty');
      return false;
    }
    
    if (content.isEmpty) {
      _log('Message content cannot be empty');
      return false;
    }
    
    try {
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.message,  // Use unified message type like Swift
        channel: channel,
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: _myPeerID!,
        senderNickname: _myNickname!,
      );
      
      return await _sendMessage(message);
    } catch (e) {
      _log('Failed to send channel message: $e');
      return false;
    }
  }
  
  /// Send a broadcast message to all connected peers (main chat)
  Future<bool> sendBroadcastMessage(String content) async {
    if (_status != BitchatStatus.running) {
      _log('Service not running, cannot send broadcast message');
      return false;
    }
    
    if (content.isEmpty) {
      _log('Broadcast message content cannot be empty');
      return false;
    }
    
    try {
      _log('📢 Sending broadcast message: "$content"');
      
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.message,  // Use unified message type like Swift
        content: content,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: _myPeerID!,
        senderNickname: _myNickname!,
        // No recipientID = broadcast to all
        recipientID: null,
        // No channel = main chat
        channel: null,
      );
      
      final success = await _sendMessage(message);
      if (success) {
        _log('✅ Broadcast message sent successfully');
      } else {
        _log('❌ Failed to send broadcast message');
      }
      return success;
    } catch (e) {
      _log('❌ Error sending broadcast message: $e');
      return false;
    }
  }
  
  /// Send announce message to broadcast our nickname
  Future<bool> sendAnnounceMessage() async {
    if (_status != BitchatStatus.running) return false;
    
    if (_myNickname == null || _myNickname!.isEmpty) {
      _log('Cannot send announce: no nickname set');
      return false;
    }
    
    try {
      // Create announce packet with nickname as payload
      final announcePacket = BitchatPacket(
        version: BinaryProtocol.version,
        type: MessageTypes.announce,  // Use announce type = 1
        ttl: 3, // Allow relay for better reach
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: Uint8List.fromList(_myPeerID!.codeUnits),
        recipientID: null, // Broadcast
        payload: Uint8List.fromList(_myNickname!.codeUnits),
        signature: null, // No signature for announce messages
      );
      
      _log('Sending announce packet: type=${announcePacket.type}, senderID=${_myPeerID}, nickname=${_myNickname}');
      
      // Send directly to BLE
      try {
        // Convert packet to binary data
        final binaryData = announcePacket.toBinaryData();
        if (binaryData != null) {
          // Send via BLE
          await _bluetoothService.sendMessage(binaryData);
          _log('Sent announce message with nickname: $_myNickname');
          return true;
        } else {
          _log('Failed to convert announce packet to binary data');
          return false;
        }
      } catch (e) {
        _log('Failed to send announce message via BLE: $e');
        return false;
      }
    } catch (e) {
      _log('Error sending announce message: $e');
      return false;
    }
  }
  
  /// Send announce message periodically
  Future<void> startPeriodicAnnounce() async {
    if (_status != BitchatStatus.running) return;
    
    // Send initial announce
    await sendAnnounceMessage();
    
    // Send periodic announces every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_status != BitchatStatus.running) {
        timer.cancel();
        return;
      }
      await sendAnnounceMessage();
    });
  }
  
  /// Join a channel
  Future<bool> joinChannel(String channelName) async {
    if (_status != BitchatStatus.running) return false;
    
    try {
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.channelJoin,
        channel: channelName,
        content: '', // Empty content for join message
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: _myPeerID!,
        senderNickname: _myNickname!,
      );
      
      return await _sendMessage(message);
    } catch (e) {
      _log('Failed to join channel: $e');
      return false;
    }
  }
  
  /// Leave a channel
  Future<bool> leaveChannel(String channelName) async {
    if (_status != BitchatStatus.running) return false;
    
    try {
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.channelLeave,
        channel: channelName,
        content: '', // Empty content for leave message
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: _myPeerID!,
        senderNickname: _myNickname!,
      );
      
      return await _sendMessage(message);
    } catch (e) {
      _log('Failed to leave channel: $e');
      return false;
    }
  }
  
  /// Get connected peers
  List<Peer> getConnectedPeers() {
    return _discoveredPeers.where((peer) => peer.isConnected).toList();
  }
  
  /// Get discovered channels
  List<Channel> getDiscoveredChannels() {
    return List.unmodifiable(_discoveredChannels);
  }
  
  /// Check if service is running
  bool get isRunning => _status == BitchatStatus.running;
  
  /// Check if service is initialized
  bool get isInitialized => _status != BitchatStatus.stopped;
  
  // Private methods
  
  void _updateStatus(BitchatStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }
  
  void _log(String message) {
    _logger.i(message);
    _logController.add(message);
  }
  
  Future<bool> _sendMessage(BitchatMessage message) async {
    try {
      // Convert message to packet
      final packet = await _messageToPacket(message);
      if (packet == null) return false;
      
      // Route message
      return await _messageRouter.routeMessage(packet);
    } catch (e) {
      _log('Error sending message: $e');
      return false;
    }
  }
  
  Future<BitchatPacket?> _messageToPacket(BitchatMessage message) async {
    try {
      // Serialize message to JSON string (compatible with Swift bitchat)
      final messageJson = message.toJson();
      final jsonString = jsonEncode(messageJson);
      final payload = Uint8List.fromList(jsonString.codeUnits);
      
      // Handle private messages with encryption
      Uint8List finalPayload = payload;
      Uint8List? signature;
      
      if (message.type == MessageTypes.message && message.recipientID != null) {
        // Encrypt private messages
        try {
          // Pad message for privacy (same as Swift)
          final blockSize = MessagePadding.optimalBlockSize(payload.length);
          final paddedPayload = MessagePadding.pad(payload, blockSize);
          
          // Encrypt the padded message
          finalPayload = await _encryptionService.encrypt(paddedPayload, message.recipientID!);
          
          // Sign the encrypted payload
          signature = await _encryptionService.sign(finalPayload);
          
          _log('Private message encrypted and signed for ${message.recipientID}');
        } catch (e) {
          _log('Failed to encrypt private message: $e');
          return null; // Don't send unencrypted private messages
        }
      } else {
        // Sign public messages (channel messages, announcements)
        try {
          signature = await _encryptionService.sign(payload);
        } catch (e) {
          _log('Failed to sign message: $e');
          // Continue without signature for public messages
        }
      }
      
      return BitchatPacket(
        version: BinaryProtocol.version,
        type: message.type,
        ttl: 7, // Default TTL
        timestamp: message.timestamp,
        senderID: Uint8List.fromList(_myPeerID!.codeUnits),
        recipientID: message.recipientID != null 
            ? Uint8List.fromList(message.recipientID!.codeUnits)
            : null,
        payload: finalPayload,
        signature: signature,
      );
    } catch (e) {
      _log('Error converting message to packet: $e');
      return null;
    }
  }
  
  void _handleIncomingMessage(BitchatMessage message) {
    try {
      // Add to stream
      _messageController.add(message);
      
      // Enhanced logging for debugging
      _log('📨 Received message:');
      _log('   Content: "${message.content}"');
      _log('   Sender: ${message.senderNickname} (${message.senderID})');
      _log('   Type: ${message.type}');
      _log('   Channel: ${message.channel ?? "main chat"}');
      _log('   Is Private: ${message.recipientID != null}');
      _log('   Timestamp: ${DateTime.fromMillisecondsSinceEpoch(message.timestamp)}');
      
      // Log message type details
      switch (message.type) {
        case MessageTypes.message:
          if (message.recipientID != null) {
            _log('🔒 Private message from ${message.senderNickname}');
          } else if (message.channel != null) {
            _log('📢 Channel message in ${message.channel} from ${message.senderNickname}');
          } else {
            _log('📢 Broadcast message from ${message.senderNickname}');
          }
          break;
        case MessageTypes.announce:
          _log('📢 Announce from ${message.senderNickname}');
          break;
        case MessageTypes.keyExchange:
          _log('🔑 Key exchange from ${message.senderID}');
          break;
        case MessageTypes.channelJoin:
          _log('➕ Channel join: ${message.channel} by ${message.senderNickname}');
          break;
        case MessageTypes.channelLeave:
          _log('➖ Channel leave: ${message.channel} by ${message.senderNickname}');
          break;
        default:
          _log('❓ Unknown message type: ${message.type}');
      }
    } catch (e) {
      _log('❌ Error handling incoming message: $e');
    }
  }
  
  void _handleKeyExchange(String peerID, Uint8List publicKeyData) {
    try {
      _log('Key exchange with peer: $peerID');
      
      // Check if peer is online
      final peer = _discoveredPeers.firstWhere(
        (p) => p.id == peerID,
        orElse: () => Peer(
          id: peerID,
          nickname: 'User${peerID.substring(0, 4)}',
          lastSeen: DateTime.now(),
          isConnected: true,
        ),
      );
      
      // Update peer list
      final existingIndex = _discoveredPeers.indexWhere((p) => p.id == peerID);
      if (existingIndex >= 0) {
        _discoveredPeers[existingIndex] = peer;
      } else {
        _discoveredPeers.add(peer);
      }
      
      // Add to stream
      _peerController.add(peer);
      
      // Check for stored messages
      if (_storeAndForward.hasStoredMessages(peerID)) {
        _storeAndForward.peerOnline(peerID);
      }
    } catch (e) {
      _log('Error handling key exchange: $e');
    }
  }
  
  void _handlePeerDiscovered(String peerId, Uint8List? publicKeyDigest) {
    try {
      // Create peer object
      final peer = Peer(
        id: peerId,
        nickname: 'User${peerId.substring(0, 4)}',
        lastSeen: DateTime.now(),
        isConnected: true,
      );
      
      // Update discovered peers list
      final existingIndex = _discoveredPeers.indexWhere((p) => p.id == peerId);
      if (existingIndex >= 0) {
        _discoveredPeers[existingIndex] = peer;
      } else {
        _discoveredPeers.add(peer);
      }
      
      // Add to stream
      _peerController.add(peer);
      
      _log('Peer discovered: ${peer.nickname}');
    } catch (e) {
      _log('Error handling peer discovery: $e');
    }
  }
  
  void _handleMessageStored(StoredMessage message) {
    _log('Message stored for offline delivery: ${message.id}');
  }
  
  void _handleMessageDelivered(StoredMessage message) {
    _log('Stored message delivered: ${message.id}');
  }
  
  void _handlePeerOnline(String peerID) {
    _log('Peer came online: $peerID');
  }
  
  String _generateMessageID() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  /// Initiate key exchange with a peer
  Future<void> _initiateKeyExchange(String peerID) async {
    try {
      _log('Initiating key exchange with peer: $peerID');
      
      // Get our public key data
      final publicKeyData = await _encryptionService.getCombinedPublicKeyData();
      if (publicKeyData == null) {
        _log('Failed to get public key data for key exchange');
        return;
      }
      
      // Create key exchange packet
      final keyExchangePacket = BitchatPacket(
        version: BinaryProtocol.version,
        type: MessageTypes.keyExchange,
        ttl: 3, // Allow relay for better reach
        timestamp: DateTime.now().millisecondsSinceEpoch,
        senderID: Uint8List.fromList(_myPeerID!.codeUnits),
        recipientID: Uint8List.fromList(peerID.codeUnits),
        payload: publicKeyData,
        signature: null, // No signature for key exchange
      );
      
      // Send key exchange packet
      final binaryData = keyExchangePacket.toBinaryData();
      if (binaryData != null) {
        await _bluetoothService.sendMessage(binaryData);
        _log('Sent key exchange to peer: $peerID');
      } else {
        _log('Failed to encode key exchange packet');
      }
    } catch (e) {
      _log('Failed to initiate key exchange: $e');
    }
  }
  
  /// Handle incoming BLE message
  void _handleIncomingBleMessage(String senderId, Uint8List data) {
    try {
      _log('📨 Received BLE message from $senderId: ${data.length} bytes');
      _log('📨 Raw data (hex): ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
      
      // Convert binary data to packet
      final packet = BitchatPacket.fromBinaryData(data);
      if (packet == null) {
        _log('❌ Failed to decode packet from $senderId');
        return;
      }
      
      _log('✅ Decoded packet: type=${packet.type}, sender=${String.fromCharCodes(packet.senderID)}');
      _log('📦 Packet details: recipientID=${packet.recipientID?.map((b) => b.toRadixString(16).padLeft(2, '0')).join() ?? "null"}, payloadLen=${packet.payload.length}');
      
      // Route the packet through message router
      _messageRouter.routeMessage(packet).then((shouldRelay) {
        if (shouldRelay) {
          _log('Relaying packet from $senderId');
          // TODO: Implement packet relay
        }
      });
      
    } catch (e) {
      _log('Error handling incoming BLE message: $e');
    }
  }
} 