/// Message router for bitchat
/// Routes messages to appropriate destinations
import 'dart:async';
import 'dart:typed_data';
import '../protocol/bitchat_packet.dart';
import '../protocol/message_types.dart';
import '../models/message.dart';
import '../models/peer.dart';
import '../encryption/encryption_service.dart';
import '../utils/message_padding.dart';
import 'dart:convert'; // Added for jsonDecode

/// Message router for bitchat network
class MessageRouter {
  static final MessageRouter _instance = MessageRouter._internal();
  factory MessageRouter() => _instance;
  MessageRouter._internal();

  // Message tracking for duplicate detection
  final Set<String> _processedMessages = {};
  final Set<String> _processedKeyExchanges = {};
  
  // Callbacks
  Function(BitchatMessage)? _onMessageReceived;
  Function(String, Uint8List)? _onKeyExchange;
  
  // Services
  EncryptionService? _encryptionService;
  
  /// Start the message router
  Future<void> start() async {
    // Initialize services
    _encryptionService = EncryptionService();
  }
  
  /// Stop the message router
  Future<void> stop() async {
    _processedMessages.clear();
    _processedKeyExchanges.clear();
  }
  
  /// Set message received callback
  void setMessageCallback(Function(BitchatMessage) callback) {
    _onMessageReceived = callback;
  }
  
  /// Set key exchange callback
  void setKeyExchangeCallback(Function(String, Uint8List) callback) {
    _onKeyExchange = callback;
  }
  
  /// Route a message through the network
  Future<bool> routeMessage(BitchatPacket packet) async {
    try {
      print('🔄 [MessageRouter] Routing packet: type=${packet.type}, sender=${String.fromCharCodes(packet.senderID)}');
      
      // Check if message is expired
      if (packet.isExpired) {
        print('❌ [MessageRouter] Packet expired');
        return false;
      }
      
      // Check for duplicate messages
      if (_processedMessages.contains(packet.messageID)) {
        print('❌ [MessageRouter] Duplicate message: ${packet.messageID}');
        return false;
      }
      
      // Mark message as processed
      _processedMessages.add(packet.messageID);
      print('✅ [MessageRouter] Message marked as processed: ${packet.messageID}');
      
      // Handle different message types
      switch (packet.type) {
        case MessageTypes.keyExchange:
          return await _handleKeyExchange(packet);
        case MessageTypes.announce:
          return await _handleAnnounce(packet);
        case MessageTypes.message:
          return await _handleUnifiedMessage(packet); // Use unified message handler
        case MessageTypes.channelMessage:
        case MessageTypes.privateMessage:
          return await _handleLegacyMessage(packet); // Handle legacy message types

        default:
          // Unknown message type, relay if TTL > 0
          return packet.ttl > 0;
      }
    } catch (e) {
      print('Error routing message: $e');
      return false;
    }
  }
  
  /// Handle key exchange messages
  Future<bool> _handleKeyExchange(BitchatPacket packet) async {
    try {
      final senderID = String.fromCharCodes(packet.senderID);
      
      // Create unique key for this exchange
      final exchangeKey = '$senderID-${packet.payload.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      
      // Check if we've already processed this key exchange
      if (_processedKeyExchanges.contains(exchangeKey)) {
        return false;
      }
      
      // Mark this key exchange as processed
      _processedKeyExchanges.add(exchangeKey);
      
      // Add peer's public key
      if (_encryptionService != null) {
        await _encryptionService!.addPeerPublicKey(senderID, packet.payload);
      }
      
      // Notify key exchange
      if (_onKeyExchange != null) {
        _onKeyExchange!(senderID, packet.payload);
      }
      
      // Relay if TTL > 0
      return packet.ttl > 0;
    } catch (e) {
      print('Error handling key exchange: $e');
      return false;
    }
  }
  
  /// Handle announce messages
  Future<bool> _handleAnnounce(BitchatPacket packet) async {
    try {
      final senderID = String.fromCharCodes(packet.senderID);
      final nickname = String.fromCharCodes(packet.payload);
      
      // Create peer object
      final peer = Peer(
        id: senderID,
        nickname: nickname,
        lastSeen: DateTime.now(),
        isConnected: true,
      );
      
      // Notify about peer discovery
      if (_onMessageReceived != null) {
        // Create a system message to indicate peer connection
        final systemMessage = BitchatMessage(
          id: 'announce-${DateTime.now().millisecondsSinceEpoch}',
          type: MessageTypes.announce,
          content: 'Peer $nickname connected',
          senderID: senderID,
          senderNickname: nickname,
          timestamp: packet.timestamp,
          isEncrypted: false,
        );
        _onMessageReceived!(systemMessage);
      }
      
      print('Received announce from peer: $senderID ($nickname)');
      return packet.ttl > 0; // Relay announce messages
    } catch (e) {
      print('Error handling announce message: $e');
      return false;
    }
  }
  
  /// Handle unified messages (type 4) - compatible with Swift bitchat
  /// This handles both private and channel messages in a unified format
  Future<bool> _handleUnifiedMessage(BitchatPacket packet) async {
    try {
      final senderID = String.fromCharCodes(packet.senderID);
      
      print('🟩 [DEBUG] Processing unified message from $senderID');
      print('🟩 [DEBUG] Packet type: ${packet.type}, recipientID: ${packet.recipientID?.map((b) => b.toRadixString(16).padLeft(2, '0')).join() ?? "null"}');
      
      // Check if this is a private message for us
      // Swift bitchat uses SpecialRecipients.broadcast = Data(repeating: 0xFF, count: 8)
      final isPrivateMessage = packet.recipientID != null && 
          !_isBroadcastRecipient(packet.recipientID!);
      
      print('🟩 [DEBUG] isPrivateMessage: $isPrivateMessage, recipientID length: ${packet.recipientID?.length ?? 0}');
      if (packet.recipientID != null) {
        print('🟩 [DEBUG] recipientID bytes: ${packet.recipientID!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
      }
      
      Uint8List messagePayload = packet.payload;
      
      if (isPrivateMessage) {
        // Handle private message decryption
        try {
          // Verify signature if present and we have the peer's signing key
          if (packet.signature != null) {
            // Check if we have the peer's signing key
            final peerSigningKey = _encryptionService!.getPeerSigningKey(senderID);
            if (peerSigningKey != null) {
              final isValid = await _encryptionService!.verify(
                packet.payload, 
                packet.signature!, 
                senderID
              );
              if (!isValid) {
                print('Invalid signature from $senderID');
                return false;
              }
            } else {
              print('No signing key for $senderID, skipping signature verification');
            }
          }
          
          // Decrypt the message
          final decryptedPadded = await _encryptionService!.decrypt(packet.payload, senderID);
          
          // Remove padding
          messagePayload = MessagePadding.unpad(decryptedPadded);
          
          print('Private message decrypted from $senderID');
        } catch (e) {
          print('Failed to decrypt private message from $senderID: $e');
          return false;
        }
      }
      
      // Parse message content from payload
      try {
        final messageJson = String.fromCharCodes(messagePayload);
        final messageData = Map<String, dynamic>.from(jsonDecode(messageJson));
        
        // Extract message fields
        final messageId = messageData['id'] as String? ?? '';
        final content = messageData['content'] as String? ?? '';
        final channel = messageData['channel'] as String?;
        final recipientID = messageData['recipientID'] as String?;
        final senderNickname = messageData['senderNickname'] as String? ?? 'Unknown';
        final timestamp = messageData['timestamp'] as int? ?? packet.timestamp;
        
        // Create BitchatMessage object
        final message = BitchatMessage(
          id: messageId,
          type: packet.type,
          content: content,
          senderID: senderID,
          senderNickname: senderNickname,
          timestamp: timestamp,
          recipientID: recipientID,
          channel: channel,
          isEncrypted: isPrivateMessage,
        );
        
        // Notify about received message
        if (_onMessageReceived != null) {
          _onMessageReceived!(message);
        }
        
        print('Received unified message from $senderID: $content');
        return packet.ttl > 0; // Relay if TTL > 0
      } catch (e) {
        print('Failed to parse message payload: $e');
        return false;
      }
    } catch (e) {
      print('Error handling unified message: $e');
      return false;
    }
  }
  
  /// Handle legacy message types (for backward compatibility)
  Future<bool> _handleLegacyMessage(BitchatPacket packet) async {
    // Legacy message handling - similar to unified but with different parsing
    return await _handleUnifiedMessage(packet);
  }
  

  
  /// Create a new packet with decremented TTL
  BitchatPacket createRelayPacket(BitchatPacket originalPacket) {
    return originalPacket.decrementTTL();
  }
  
  /// Check if message should be relayed
  bool shouldRelay(BitchatPacket packet) {
    return packet.ttl > 0 && !packet.isExpired;
  }
  
  /// Get processed message count
  int getProcessedMessageCount() {
    return _processedMessages.length;
  }
  
  /// Clear processed messages (for memory management)
  void clearProcessedMessages() {
    _processedMessages.clear();
    _processedKeyExchanges.clear();
  }
  
  /// Check if recipientID is the broadcast recipient (8 bytes of 0xFF)
  bool _isBroadcastRecipient(Uint8List recipientID) {
    return recipientID.length == 8 && 
           recipientID.every((byte) => byte == 0xFF);
  }
} 