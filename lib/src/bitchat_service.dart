/// Main bitchat service that coordinates all bitchat functionality
/// 
/// This is the primary interface for bitchat operations including
/// Bluetooth mesh networking, message routing, and encryption.
import 'dart:async';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

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
      
      // Request permissions
      final bluetoothStatus = await Permission.bluetooth.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      
      if (bluetoothStatus != PermissionStatus.granted ||
          bluetoothScanStatus != PermissionStatus.granted ||
          bluetoothConnectStatus != PermissionStatus.granted) {
        _log('Bluetooth permissions not granted');
        _updateStatus(BitchatStatus.error);
        return false;
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
      
      // Start BLE advertising
      await _bluetoothService.startAdvertising(
        peerId: peerID,
        publicKeyDigest: publicKeyData,
      );
      
      // Start message router
      await _messageRouter.start();
      
      // Start store and forward
      await _storeAndForward.start();
      
      _updateStatus(BitchatStatus.running);
      _log('Bitchat service started successfully');
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
  
  /// Send a channel message
  Future<bool> sendChannelMessage(String channelName, String content) async {
    if (_status != BitchatStatus.running) {
      _log('Service not running, cannot send message');
      return false;
    }
    
    if (channelName.isEmpty || !channelName.startsWith('#')) {
      _log('Invalid channel name: $channelName');
      return false;
    }
    
    if (content.isEmpty) {
      _log('Message content cannot be empty');
      return false;
    }
    
    try {
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.channelMessage,
        channel: channelName,
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
      _log('No encryption keys for peer $recipientID, message will be queued');
      // TODO: Queue message for when keys are available
    }
    
    try {
      final message = BitchatMessage(
        id: _generateMessageID(),
        type: MessageTypes.privateMessage,
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
      // Serialize message to JSON string
      final messageJson = message.toJson();
      final jsonString = messageJson.toString();
      final payload = Uint8List.fromList(jsonString.codeUnits);
      
      // Handle private messages with encryption
      Uint8List finalPayload = payload;
      Uint8List? signature;
      
      if (message.type == MessageTypes.privateMessage && message.recipientID != null) {
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
      
      _log('Received message: ${message.content}');
    } catch (e) {
      _log('Error handling incoming message: $e');
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
} 