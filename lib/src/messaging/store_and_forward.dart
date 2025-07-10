/// Store and forward service for bitchat
/// Handles message caching and retransmission
import 'dart:async';
import 'dart:typed_data';
import '../protocol/bitchat_packet.dart';

/// Stored message for offline delivery
class StoredMessage {
  final String id;
  final String senderID;
  final String? recipientID;
  final String? channel;
  final String content;
  final int timestamp;
  final bool isPrivate;
  final bool isEncrypted;
  final Uint8List? encryptedContent;
  
  const StoredMessage({
    required this.id,
    required this.senderID,
    this.recipientID,
    this.channel,
    required this.content,
    required this.timestamp,
    required this.isPrivate,
    required this.isEncrypted,
    this.encryptedContent,
  });
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderID': senderID,
      'recipientID': recipientID,
      'channel': channel,
      'content': content,
      'timestamp': timestamp,
      'isPrivate': isPrivate,
      'isEncrypted': isEncrypted,
      'encryptedContent': encryptedContent?.map((b) => b).toList(),
    };
  }
  
  /// Create from JSON
  factory StoredMessage.fromJson(Map<String, dynamic> json) {
    return StoredMessage(
      id: json['id'] as String,
      senderID: json['senderID'] as String,
      recipientID: json['recipientID'] as String?,
      channel: json['channel'] as String?,
      content: json['content'] as String,
      timestamp: json['timestamp'] as int,
      isPrivate: json['isPrivate'] as bool,
      isEncrypted: json['isEncrypted'] as bool,
      encryptedContent: json['encryptedContent'] != null 
          ? Uint8List.fromList(List<int>.from(json['encryptedContent']))
          : null,
    );
  }
}

/// Store and forward service for bitchat
class StoreAndForward {
  static final StoreAndForward _instance = StoreAndForward._internal();
  factory StoreAndForward() => _instance;
  StoreAndForward._internal();
  
  // Message storage
  final Map<String, List<StoredMessage>> _storedMessages = {};
  final Map<String, List<StoredMessage>> _favoriteMessages = {};
  
  // Configuration
  static const int maxRetentionHours = 12; // Regular messages
  static const int maxRetentionHoursFavorites = 168; // 1 week for favorites
  
  // Callbacks
  Function(StoredMessage)? _onMessageStored;
  Function(StoredMessage)? _onMessageDelivered;
  Function(String)? _onPeerOnline;
  
  /// Start the store and forward service
  Future<void> start() async {
    // Initialize storage
    _storedMessages.clear();
    _favoriteMessages.clear();
  }
  
  /// Stop the store and forward service
  Future<void> stop() async {
    // Clean up old messages
    _cleanupOldMessages();
  }
  
  /// Set message stored callback
  void setMessageStoredCallback(Function(StoredMessage) callback) {
    _onMessageStored = callback;
  }
  
  /// Set message delivered callback
  void setMessageDeliveredCallback(Function(StoredMessage) callback) {
    _onMessageDelivered = callback;
  }
  
  /// Set peer online callback
  void setPeerOnlineCallback(Function(String) callback) {
    _onPeerOnline = callback;
  }
  
  /// Store a message for offline delivery
  Future<void> storeMessage(BitchatPacket packet, {bool isFavorite = false}) async {
    try {
      final senderID = String.fromCharCodes(packet.senderID);
      final recipientID = packet.recipientID != null 
          ? String.fromCharCodes(packet.recipientID!)
          : null;
      
      // Parse message content
      final content = String.fromCharCodes(packet.payload);
      
      // Create stored message
      final storedMessage = StoredMessage(
        id: packet.messageID,
        senderID: senderID,
        recipientID: recipientID,
        content: content,
        timestamp: packet.timestamp,
        isPrivate: packet.isPrivate,
        isEncrypted: packet.isSigned,
        encryptedContent: packet.isSigned ? packet.payload : null,
      );
      
      // Store based on recipient
      final targetID = recipientID ?? senderID;
      if (isFavorite) {
        _favoriteMessages.putIfAbsent(targetID, () => []).add(storedMessage);
      } else {
        _storedMessages.putIfAbsent(targetID, () => []).add(storedMessage);
      }
      
      // Notify message stored
      if (_onMessageStored != null) {
        _onMessageStored!(storedMessage);
      }
    } catch (e) {
      print('Error storing message: $e');
    }
  }
  
  /// Check if peer has stored messages
  bool hasStoredMessages(String peerID) {
    final regularMessages = _storedMessages[peerID]?.isNotEmpty ?? false;
    final favoriteMessages = _favoriteMessages[peerID]?.isNotEmpty ?? false;
    return regularMessages || favoriteMessages;
  }
  
  /// Get stored messages for a peer
  List<StoredMessage> getStoredMessages(String peerID) {
    final regularMessages = _storedMessages[peerID] ?? [];
    final favoriteMessages = _favoriteMessages[peerID] ?? [];
    return [...regularMessages, ...favoriteMessages];
  }
  
  /// Mark peer as online and deliver stored messages
  Future<void> peerOnline(String peerID) async {
    try {
      // Get stored messages
      final messages = getStoredMessages(peerID);
      if (messages.isEmpty) return;
      
      // Notify peer online
      if (_onPeerOnline != null) {
        _onPeerOnline!(peerID);
      }
      
      // Deliver messages
      for (final message in messages) {
        if (_onMessageDelivered != null) {
          _onMessageDelivered!(message);
        }
      }
      
      // Clear stored messages
      _storedMessages.remove(peerID);
      _favoriteMessages.remove(peerID);
    } catch (e) {
      print('Error delivering stored messages: $e');
    }
  }
  
  /// Add peer to favorites
  void addToFavorites(String peerID) {
    final regularMessages = _storedMessages[peerID];
    if (regularMessages != null) {
      _favoriteMessages.putIfAbsent(peerID, () => []).addAll(regularMessages);
      _storedMessages.remove(peerID);
    }
  }
  
  /// Remove peer from favorites
  void removeFromFavorites(String peerID) {
    final favoriteMessages = _favoriteMessages[peerID];
    if (favoriteMessages != null) {
      _storedMessages.putIfAbsent(peerID, () => []).addAll(favoriteMessages);
      _favoriteMessages.remove(peerID);
    }
  }
  
  /// Clean up old messages
  void _cleanupOldMessages() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeRegular = maxRetentionHours * 60 * 60 * 1000;
    final maxAgeFavorites = maxRetentionHoursFavorites * 60 * 60 * 1000;
    
    // Clean regular messages
    for (final peerID in _storedMessages.keys) {
      _storedMessages[peerID]!.removeWhere((message) {
        return now - message.timestamp > maxAgeRegular;
      });
      if (_storedMessages[peerID]!.isEmpty) {
        _storedMessages.remove(peerID);
      }
    }
    
    // Clean favorite messages
    for (final peerID in _favoriteMessages.keys) {
      _favoriteMessages[peerID]!.removeWhere((message) {
        return now - message.timestamp > maxAgeFavorites;
      });
      if (_favoriteMessages[peerID]!.isEmpty) {
        _favoriteMessages.remove(peerID);
      }
    }
  }
  
  /// Get storage statistics
  Map<String, dynamic> getStorageStats() {
    int totalRegular = 0;
    int totalFavorites = 0;
    
    for (final messages in _storedMessages.values) {
      totalRegular += messages.length;
    }
    
    for (final messages in _favoriteMessages.values) {
      totalFavorites += messages.length;
    }
    
    return {
      'regularMessages': totalRegular,
      'favoriteMessages': totalFavorites,
      'totalPeers': _storedMessages.length + _favoriteMessages.length,
    };
  }
  
  /// Clear all stored messages
  void clearAllMessages() {
    _storedMessages.clear();
    _favoriteMessages.clear();
  }
  
  /// Get all peer IDs with stored messages
  List<String> getPeersWithMessages() {
    final Set<String> peers = {};
    peers.addAll(_storedMessages.keys);
    peers.addAll(_favoriteMessages.keys);
    return peers.toList();
  }
} 