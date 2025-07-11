/// Bitchat data models for bitchat-flutter-plugin
/// Defines peer and message structures for bitchat functionality

/// Bitchat message types
enum BitchatMessageType {
  channelMessage,
  privateMessage,
  channelJoin,
  channelLeave,
  unknown,
}

/// Bitchat peer information
class BitchatPeer {
  final String id;
  final String nickname;
  final DateTime lastSeen;
  final bool isConnected;

  const BitchatPeer({
    required this.id,
    required this.nickname,
    required this.lastSeen,
    required this.isConnected,
  });

  /// Create from JSON
  factory BitchatPeer.fromJson(Map<String, dynamic> json) {
    return BitchatPeer(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      isConnected: json['isConnected'] as bool,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'lastSeen': lastSeen.toIso8601String(),
      'isConnected': isConnected,
    };
  }

  @override
  String toString() {
    return 'BitchatPeer(id: $id, nickname: $nickname, isConnected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BitchatPeer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Bitchat message data for 0xchat integration
class BitchatMessageData {
  final String id;
  final BitchatMessageType type;
  final String content;
  final String? channel;
  final String? recipientID;
  final DateTime timestamp;
  final String senderID;
  final String senderNickname;

  const BitchatMessageData({
    required this.id,
    required this.type,
    required this.content,
    this.channel,
    this.recipientID,
    required this.timestamp,
    required this.senderID,
    required this.senderNickname,
  });

  /// Create from JSON
  factory BitchatMessageData.fromJson(Map<String, dynamic> json) {
    return BitchatMessageData(
      id: json['id'] as String,
      type: _parseMessageType(json['type'] as String),
      content: json['content'] as String,
      channel: json['channel'] as String?,
      recipientID: json['recipientID'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      senderID: json['senderID'] as String,
      senderNickname: json['senderNickname'] as String,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': _messageTypeToString(type),
      'content': content,
      'channel': channel,
      'recipientID': recipientID,
      'timestamp': timestamp.toIso8601String(),
      'senderID': senderID,
      'senderNickname': senderNickname,
    };
  }

  /// Check if message is a channel message
  bool get isChannelMessage => type == BitchatMessageType.channelMessage;

  /// Check if message is a private message
  bool get isPrivateMessage => type == BitchatMessageType.privateMessage;

  /// Check if message is a channel join
  bool get isChannelJoin => type == BitchatMessageType.channelJoin;

  /// Check if message is a channel leave
  bool get isChannelLeave => type == BitchatMessageType.channelLeave;

  @override
  String toString() {
    return 'BitchatMessageData(id: $id, type: $type, content: $content, sender: $senderNickname)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BitchatMessageData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Helper methods for message type conversion
  static BitchatMessageType _parseMessageType(String type) {
    switch (type) {
      case 'channel_message':
        return BitchatMessageType.channelMessage;
      case 'private_message':
        return BitchatMessageType.privateMessage;
      case 'channel_join':
        return BitchatMessageType.channelJoin;
      case 'channel_leave':
        return BitchatMessageType.channelLeave;
      default:
        return BitchatMessageType.unknown;
    }
  }

  static String _messageTypeToString(BitchatMessageType type) {
    switch (type) {
      case BitchatMessageType.channelMessage:
        return 'channel_message';
      case BitchatMessageType.privateMessage:
        return 'private_message';
      case BitchatMessageType.channelJoin:
        return 'channel_join';
      case BitchatMessageType.channelLeave:
        return 'channel_leave';
      case BitchatMessageType.unknown:
        return 'unknown';
    }
  }
} 