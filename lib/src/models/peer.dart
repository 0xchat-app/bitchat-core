/// Represents a peer in the bitchat network
class Peer {
  /// Unique identifier for the peer
  final String id;
  
  /// Human-readable nickname
  final String nickname;
  
  /// RSSI signal strength (-100 to 0)
  final int rssi;
  
  /// Last seen timestamp
  final DateTime lastSeen;
  
  /// Whether this peer is currently connected
  final bool isConnected;
  
  /// Whether this peer is blocked
  final bool isBlocked;
  
  /// Whether this peer is a favorite
  final bool isFavorite;
  
  const Peer({
    required this.id,
    required this.nickname,
    this.rssi = 0,
    required this.lastSeen,
    this.isConnected = false,
    this.isBlocked = false,
    this.isFavorite = false,
  });
  
  /// Create a copy with updated fields
  Peer copyWith({
    String? id,
    String? nickname,
    int? rssi,
    DateTime? lastSeen,
    bool? isConnected,
    bool? isBlocked,
    bool? isFavorite,
  }) {
    return Peer(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      isConnected: isConnected ?? this.isConnected,
      isBlocked: isBlocked ?? this.isBlocked,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'rssi': rssi,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'isConnected': isConnected,
      'isBlocked': isBlocked,
      'isFavorite': isFavorite,
    };
  }
  
  /// Create from JSON
  factory Peer.fromJson(Map<String, dynamic> json) {
    return Peer(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      rssi: json['rssi'] as int? ?? 0,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
      isConnected: json['isConnected'] as bool? ?? false,
      isBlocked: json['isBlocked'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
  
  @override
  String toString() {
    return 'Peer(id: $id, nickname: $nickname, rssi: $rssi, connected: $isConnected)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Peer && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
} 