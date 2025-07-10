/// Represents a channel in the bitchat network
class Channel {
  /// Channel name (e.g., "#general")
  final String name;
  
  /// Channel description
  final String? description;
  
  /// Channel owner ID
  final String? ownerID;
  
  /// Whether channel is password protected
  final bool isPasswordProtected;
  
  /// Whether message retention is enabled
  final bool messageRetention;
  
  /// Number of active users in channel
  final int userCount;
  
  /// Last activity timestamp
  final DateTime lastActivity;
  
  /// Whether user is joined to this channel
  final bool isJoined;
  
  /// Channel password (if joined and password protected)
  final String? password;
  
  const Channel({
    required this.name,
    this.description,
    this.ownerID,
    this.isPasswordProtected = false,
    this.messageRetention = false,
    this.userCount = 0,
    required this.lastActivity,
    this.isJoined = false,
    this.password,
  });
  
  /// Create a copy with updated fields
  Channel copyWith({
    String? name,
    String? description,
    String? ownerID,
    bool? isPasswordProtected,
    bool? messageRetention,
    int? userCount,
    DateTime? lastActivity,
    bool? isJoined,
    String? password,
  }) {
    return Channel(
      name: name ?? this.name,
      description: description ?? this.description,
      ownerID: ownerID ?? this.ownerID,
      isPasswordProtected: isPasswordProtected ?? this.isPasswordProtected,
      messageRetention: messageRetention ?? this.messageRetention,
      userCount: userCount ?? this.userCount,
      lastActivity: lastActivity ?? this.lastActivity,
      isJoined: isJoined ?? this.isJoined,
      password: password ?? this.password,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'ownerID': ownerID,
      'isPasswordProtected': isPasswordProtected,
      'messageRetention': messageRetention,
      'userCount': userCount,
      'lastActivity': lastActivity.millisecondsSinceEpoch,
      'isJoined': isJoined,
      'password': password,
    };
  }
  
  /// Create from JSON
  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name'] as String,
      description: json['description'] as String?,
      ownerID: json['ownerID'] as String?,
      isPasswordProtected: json['isPasswordProtected'] as bool? ?? false,
      messageRetention: json['messageRetention'] as bool? ?? false,
      userCount: json['userCount'] as int? ?? 0,
      lastActivity: DateTime.fromMillisecondsSinceEpoch(json['lastActivity'] as int),
      isJoined: json['isJoined'] as bool? ?? false,
      password: json['password'] as String?,
    );
  }
  
  /// Check if channel is public (no password)
  bool get isPublic => !isPasswordProtected;
  
  /// Check if channel is private (password protected)
  bool get isPrivate => isPasswordProtected;
  
  /// Check if user is the owner of this channel
  bool isOwner(String userID) => ownerID == userID;
  
  @override
  String toString() {
    return 'Channel(name: $name, users: $userCount, joined: $isJoined)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Channel && other.name == name;
  }
  
  @override
  int get hashCode => name.hashCode;
} 