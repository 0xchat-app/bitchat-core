/// Represents a message in the bitchat network
class BitchatMessage {
  /// Unique message ID
  final String id;
  
  /// Message type (see MessageTypes)
  final int type;
  
  /// Message content
  final String content;
  
  /// Sender ID
  final String senderID;
  
  /// Sender nickname
  final String senderNickname;
  
  /// Recipient ID (for private messages)
  final String? recipientID;
  
  /// Channel name (for channel messages)
  final String? channel;
  
  /// Timestamp in milliseconds since epoch
  final int timestamp;
  
  /// Whether message has been delivered
  final bool isDelivered;
  
  /// Whether message has been read
  final bool isRead;
  
  /// Whether message is encrypted
  final bool isEncrypted;
  
  /// Message signature (for verification)
  final String? signature;
  
  const BitchatMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.senderID,
    required this.senderNickname,
    this.recipientID,
    this.channel,
    required this.timestamp,
    this.isDelivered = false,
    this.isRead = false,
    this.isEncrypted = false,
    this.signature,
  });
  
  /// Create a copy with updated fields
  BitchatMessage copyWith({
    String? id,
    int? type,
    String? content,
    String? senderID,
    String? senderNickname,
    String? recipientID,
    String? channel,
    int? timestamp,
    bool? isDelivered,
    bool? isRead,
    bool? isEncrypted,
    String? signature,
  }) {
    return BitchatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      senderID: senderID ?? this.senderID,
      senderNickname: senderNickname ?? this.senderNickname,
      recipientID: recipientID ?? this.recipientID,
      channel: channel ?? this.channel,
      timestamp: timestamp ?? this.timestamp,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      signature: signature ?? this.signature,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'content': content,
      'senderID': senderID,
      'senderNickname': senderNickname,
      'recipientID': recipientID,
      'channel': channel,
      'timestamp': timestamp,
      'isDelivered': isDelivered,
      'isRead': isRead,
      'isEncrypted': isEncrypted,
      'signature': signature,
    };
  }
  
  /// Create from JSON
  factory BitchatMessage.fromJson(Map<String, dynamic> json) {
    return BitchatMessage(
      id: json['id'] as String,
      type: json['type'] as int,
      content: json['content'] as String,
      senderID: json['senderID'] as String,
      senderNickname: json['senderNickname'] as String,
      recipientID: json['recipientID'] as String?,
      channel: json['channel'] as String?,
      timestamp: json['timestamp'] as int,
      isDelivered: json['isDelivered'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      signature: json['signature'] as String?,
    );
  }
  
  /// Check if this is a channel message
  bool get isChannelMessage => channel != null;
  
  /// Check if this is a private message
  bool get isPrivateMessage => recipientID != null;
  
  /// Check if this is a system message
  bool get isSystemMessage => type >= 0 && type <= 9;
  
  /// Get message timestamp as DateTime
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
  
  /// Get formatted timestamp
  String get formattedTime {
    final now = DateTime.now();
    final messageTime = dateTime;
    final difference = now.difference(messageTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
  
  @override
  String toString() {
    return 'BitchatMessage(id: $id, type: $type, content: $content, sender: $senderNickname)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BitchatMessage && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
} 