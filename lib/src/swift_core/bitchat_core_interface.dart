import 'dart:async';
import 'package:flutter/services.dart';

/// Core Bitchat interface that wraps Swift implementation
/// Provides simplified access to key functionality
class BitchatCoreInterface {
  static const String _channelName = 'bitchat_core';
  static const MethodChannel _methodChannel = MethodChannel(_channelName);
  static const EventChannel _eventChannel = EventChannel('bitchat_core_events');
  
  // Singleton instance
  static final BitchatCoreInterface _instance = BitchatCoreInterface._internal();
  factory BitchatCoreInterface() => _instance;
  BitchatCoreInterface._internal();

  // Event streams
  final StreamController<List<PeerInfo>> _peerListController = 
      StreamController<List<PeerInfo>>.broadcast();
  final StreamController<BitchatMessage> _messageController = 
      StreamController<BitchatMessage>.broadcast();
  final StreamController<ConnectionStatus> _connectionController = 
      StreamController<ConnectionStatus>.broadcast();

  // Streams for external consumption
  Stream<List<PeerInfo>> get peerListStream => _peerListController.stream;
  Stream<BitchatMessage> get messageStream => _messageController.stream;
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;

  bool _isInitialized = false;
  String? _myPeerId;
  StreamSubscription<dynamic>? _eventSubscription;

  /// Initialize the bitchat core service
  /// Returns true if initialization successful
  Future<bool> initialize({
    required String myPeerId,
    String? nickname,
    bool enableBluetooth = true,
    bool enableMesh = true,
  }) async {
    try {
      // Call Swift initialization
      final result = await _methodChannel.invokeMethod('initialize', {
        'myPeerId': myPeerId,
        'nickname': nickname ?? myPeerId,
        'enableBluetooth': enableBluetooth,
        'enableMesh': enableMesh,
      });

      if (result is bool && result) {
        _isInitialized = true;
        _myPeerId = myPeerId;
        _setupEventListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('BitchatCoreInterface: Failed to initialize: $e');
      return false;
    }
  }

  /// Start the bitchat service
  Future<bool> start() async {
    if (!_isInitialized) {
      throw StateError('BitchatCoreInterface not initialized');
    }

    try {
      final result = await _methodChannel.invokeMethod('start');
      return result is bool ? result : false;
    } catch (e) {
      print('BitchatCoreInterface: Failed to start: $e');
      return false;
    }
  }

  /// Stop the bitchat service
  Future<bool> stop() async {
    try {
      final result = await _methodChannel.invokeMethod('stop');
      return result is bool ? result : false;
    } catch (e) {
      print('BitchatCoreInterface: Failed to stop: $e');
      return false;
    }
  }

  /// Get current peer list
  Future<List<PeerInfo>> getPeerList() async {
    try {
      final result = await _methodChannel.invokeMethod('getPeerList');
      if (result is List) {
        return result.map((peer) => PeerInfo.fromMap(peer)).toList();
      }
      return [];
    } catch (e) {
      print('BitchatCoreInterface: Failed to get peer list: $e');
      return [];
    }
  }

  /// Send a message to a specific peer or broadcast
  Future<bool> sendMessage({
    required String message,
    String? recipientId, // null for broadcast
    MessageType type = MessageType.message,
    int ttl = 5,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('sendMessage', {
        'message': message,
        'recipientId': recipientId,
        'type': type.index,
        'ttl': ttl,
      });
      return result is bool ? result : false;
    } catch (e) {
      print('BitchatCoreInterface: Failed to send message: $e');
      return false;
    }
  }

  /// Get my peer ID
  String? get myPeerId => _myPeerId;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Setup event listeners for Swift callbacks
  void _setupEventListeners() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map<String, dynamic>) {
        final eventType = event['type'] as String?;
        final data = event['data'];
        
        switch (eventType) {
          case 'peerList':
            if (data is List) {
              final peerList = data.map((peer) => PeerInfo.fromMap(peer)).toList();
              _peerListController.add(peerList);
            }
            break;
          case 'message':
            if (data is Map<String, dynamic>) {
              final message = BitchatMessage.fromMap(data);
              _messageController.add(message);
            }
            break;
          case 'connection':
            if (data is Map<String, dynamic>) {
              final status = ConnectionStatus.fromMap(data);
              _connectionController.add(status);
            }
            break;
        }
      }
    });
  }

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _peerListController.close();
    _messageController.close();
    _connectionController.close();
  }
}

/// Peer information model
class PeerInfo {
  final String id;
  final String nickname;
  final int rssi;
  final DateTime lastSeen;
  final bool isConnected;

  PeerInfo({
    required this.id,
    required this.nickname,
    required this.rssi,
    required this.lastSeen,
    required this.isConnected,
  });

  factory PeerInfo.fromMap(Map<String, dynamic> map) {
    return PeerInfo(
      id: map['id'] ?? '',
      nickname: map['nickname'] ?? '',
      rssi: map['rssi'] ?? 0,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] ?? 0),
      isConnected: map['isConnected'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'rssi': rssi,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'isConnected': isConnected,
    };
  }
}

/// Message model
class BitchatMessage {
  final String id;
  final String senderId;
  final String? recipientId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isBroadcast;

  BitchatMessage({
    required this.id,
    required this.senderId,
    this.recipientId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isBroadcast,
  });

  factory BitchatMessage.fromMap(Map<String, dynamic> map) {
    return BitchatMessage(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'],
      content: map['content'] ?? '',
      type: MessageType.values[map['type'] ?? 0],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      isBroadcast: map['isBroadcast'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isBroadcast': isBroadcast,
    };
  }
}

/// Connection status model
class ConnectionStatus {
  final bool isConnected;
  final int peerCount;
  final String? error;

  ConnectionStatus({
    required this.isConnected,
    required this.peerCount,
    this.error,
  });

  factory ConnectionStatus.fromMap(Map<String, dynamic> map) {
    return ConnectionStatus(
      isConnected: map['isConnected'] ?? false,
      peerCount: map['peerCount'] ?? 0,
      error: map['error'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isConnected': isConnected,
      'peerCount': peerCount,
      'error': error,
    };
  }
}

/// Message types matching Swift enum
enum MessageType {
  announce,
  keyExchange,
  leave,
  message,
  fragmentStart,
  fragmentContinue,
  fragmentEnd,
  channelAnnounce,
  channelRetention,
  deliveryAck,
  deliveryStatusRequest,
  readReceipt,
} 