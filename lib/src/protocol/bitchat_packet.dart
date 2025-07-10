/// Represents a bitchat network packet
/// 
/// This is the core data structure for all bitchat communication
/// containing message metadata, routing information, and payload.
import 'dart:typed_data';
import 'binary_protocol.dart';

class BitchatPacket {
  /// Protocol version (currently 1)
  final int version;
  
  /// Message type (see MessageTypes)
  final int type;
  
  /// Time-to-live for message routing (max 7 hops)
  final int ttl;
  
  /// Timestamp in milliseconds since epoch
  final int timestamp;
  
  /// Sender's unique identifier (8 bytes)
  final Uint8List senderID;
  
  /// Recipient's unique identifier (8 bytes, null for broadcast)
  final Uint8List? recipientID;
  
  /// Message payload
  final Uint8List payload;
  
  /// Digital signature (64 bytes, null if unsigned)
  final Uint8List? signature;
  
  const BitchatPacket({
    required this.version,
    required this.type,
    required this.ttl,
    required this.timestamp,
    required this.senderID,
    this.recipientID,
    required this.payload,
    this.signature,
  });
  
  /// Create a new packet with decremented TTL
  BitchatPacket decrementTTL() {
    return BitchatPacket(
      version: version,
      type: type,
      ttl: ttl > 0 ? ttl - 1 : 0,
      timestamp: timestamp,
      senderID: senderID,
      recipientID: recipientID,
      payload: payload,
      signature: signature,
    );
  }
  
  /// Check if packet has expired (TTL = 0)
  bool get isExpired => ttl == 0;
  
  /// Check if this is a broadcast message
  bool get isBroadcast => recipientID == null;
  
  /// Check if this is a private message
  bool get isPrivate => recipientID != null;
  
  /// Check if this packet is signed
  bool get isSigned => signature != null;
  
  /// Get unique message ID for deduplication
  String get messageID {
    final combined = Uint8List.fromList([
      ...senderID,
      ...payload,
      ...timestamp.toString().codeUnits,
    ]);
    final hash = _simpleHash(combined);
    return hash.toRadixString(16).padLeft(16, '0');
  }
  
  /// Simple hash function for message ID generation
  int _simpleHash(Uint8List data) {
    int hash = 0;
    for (int i = 0; i < data.length; i++) {
      hash = ((hash << 5) - hash + data[i]) & 0xFFFFFFFF;
    }
    return hash;
  }
  
  @override
  String toString() {
    return 'BitchatPacket(type: $type, ttl: $ttl, sender: ${senderID.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}, payload: ${payload.length} bytes)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BitchatPacket &&
        other.version == version &&
        other.type == type &&
        other.timestamp == timestamp &&
        other.senderID.length == senderID.length &&
        other.payload.length == payload.length;
  }
  
  @override
  int get hashCode {
    return Object.hash(version, type, timestamp, senderID.length, payload.length);
  }
  
  /// Convert packet to binary data for transmission
  Uint8List? toBinaryData() {
    return BinaryProtocol.encode(this);
  }
  
  /// Create packet from binary data
  static BitchatPacket? fromBinaryData(Uint8List data) {
    return BinaryProtocol.decode(data);
  }
} 