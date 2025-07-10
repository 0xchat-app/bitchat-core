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
      // Check if message is expired
      if (packet.isExpired) {
        return false;
      }
      
      // Check for duplicate messages
      if (_processedMessages.contains(packet.messageID)) {
        return false;
      }
      
      // Mark message as processed
      _processedMessages.add(packet.messageID);
      
      // Handle different message types
      switch (packet.type) {
        case MessageTypes.keyExchange:
          return await _handleKeyExchange(packet);
        case MessageTypes.announce:
          return await _handleAnnounce(packet);
        case MessageTypes.message:
          return await _handleChatMessage(packet);
        case MessageTypes.channelMessage:
        case MessageTypes.privateMessage:
          return await _handleChatMessage(packet);

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
  
  /// Handle chat messages (channel and private)
  Future<bool> _handleChatMessage(BitchatPacket packet) async {
    try {
      final senderID = String.fromCharCodes(packet.senderID);
      
      // Check if this is a private message for us
      final isPrivateMessage = packet.recipientID != null && 
          String.fromCharCodes(packet.recipientID!) != 'broadcast';
      
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
      } else {
        // Handle public message signature verification
        if (packet.signature != null) {
          try {
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
          } catch (e) {
            print('Failed to verify signature from $senderID: $e');
            // Continue without signature verification for public messages
          }
        }
      }
      
      // Parse message content
      final messageContent = String.fromCharCodes(messagePayload);
      
      // Create message object
      final message = BitchatMessage(
        id: packet.messageID,
        type: packet.type,
        content: messageContent,
        senderID: senderID,
        senderNickname: 'User${senderID.substring(0, 4)}',
        timestamp: packet.timestamp,
        isEncrypted: isPrivateMessage,
        recipientID: isPrivateMessage ? String.fromCharCodes(packet.recipientID!) : null,
      );
      
      // Notify message received
      if (_onMessageReceived != null) {
        _onMessageReceived!(message);
      }
      
      // Relay if TTL > 0
      return packet.ttl > 0;
    } catch (e) {
      print('Error handling chat message: $e');
      return false;
    }
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
} 