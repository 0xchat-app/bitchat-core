import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'bluetooth_mesh_service.dart' show PeerDiscoveredCallback;

/// iOS BLE Service
/// Provides both BLE peripheral and central functionality using iOS native code
class IOSBlePeripheralService {
  static const MethodChannel _channel = MethodChannel('com.bitchat.core/ble_peripheral');
  
  static final IOSBlePeripheralService _instance = IOSBlePeripheralService._internal();
  factory IOSBlePeripheralService() => _instance;
  IOSBlePeripheralService._internal();
  
  bool _isInitialized = false;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamController<Map<String, dynamic>>? _peerController;
  PeerDiscoveredCallback? _onPeerDiscovered;
  
  /// Initialize the peripheral service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // Set up message listener
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
      _channel.setMethodCallHandler(_handleMethodCall);
      
              _isInitialized = true;
        return true;
      } catch (e) {
        print('Failed to initialize iOS BLE peripheral service: $e');
        return false;
      }
  }
  
  /// Start BLE peripheral service
  Future<bool> startService({
    required String peerID,
    required String nickname,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    try {
      final result = await _channel.invokeMethod('startPeripheralService', {
        'peerID': peerID,
        'nickname': nickname,
              });
        
        return result == true;
      } catch (e) {
        print('Failed to start iOS BLE peripheral service: $e');
        return false;
      }
  }
  
  /// Stop BLE peripheral service
  Future<bool> stopService() async {
          try {
        final result = await _channel.invokeMethod('stopPeripheralService');
        return result == true;
      } catch (e) {
        print('Failed to stop iOS BLE peripheral service: $e');
        return false;
      }
  }
  
  /// Send announce message
  Future<bool> sendAnnounceMessage() async {
    try {
      final result = await _channel.invokeMethod('sendAnnounceMessage');
      return result == true;
    } catch (e) {
      print('Failed to send announce message: $e');
      return false;
    }
  }
  
  /// Send key exchange message
  Future<bool> sendKeyExchangeMessage() async {
    try {
      final result = await _channel.invokeMethod('sendKeyExchangeMessage');
      return result == true;
    } catch (e) {
      print('Failed to send key exchange message: $e');
      return false;
    }
  }
  
  /// Send message via BLE
  Future<bool> sendMessage(Uint8List data) async {
    try {
      final result = await _channel.invokeMethod('sendMessage', {'data': data});
      return result == true;
    } catch (e) {
      print('Failed to send message via iOS BLE: $e');
      return false;
    }
  }
  
  // Central service methods
  /// Start BLE scanning
  Future<bool> startScanning({PeerDiscoveredCallback? onPeer}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    _onPeerDiscovered = onPeer;
    
    try {
      final result = await _channel.invokeMethod('startScanning');
      return result == true;
    } catch (e) {
      print('Failed to start iOS BLE scanning: $e');
      return false;
    }
  }
  
  /// Stop BLE scanning
  Future<bool> stopScanning() async {
    try {
      final result = await _channel.invokeMethod('stopScanning');
      return result == true;
    } catch (e) {
      print('Failed to stop iOS BLE scanning: $e');
      return false;
    }
  }
  
  /// Check if currently scanning
  Future<bool> isScanning() async {
    try {
      final result = await _channel.invokeMethod('isScanning');
      return result == true;
    } catch (e) {
      print('Failed to check scanning status: $e');
      return false;
    }
  }
  
  /// Get message stream
  Stream<Map<String, dynamic>> get messageStream {
    if (_messageController == null) {
      _messageController = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _messageController!.stream;
  }
  
  /// Get peer discovery stream
  Stream<Map<String, dynamic>> get peerStream {
    if (_peerController == null) {
      _peerController = StreamController<Map<String, dynamic>>.broadcast();
    }
    return _peerController!.stream;
  }
  
  /// Handle method calls from iOS
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMessageReceived':
        final args = call.arguments as Map<String, dynamic>;
        final senderId = args['senderId'] as String;
        final payload = args['payload'] as Uint8List;
        

        
        // Add to message stream
        _messageController?.add({
          'senderId': senderId,
          'payload': payload,
        });
        break;
        
      case 'onPeerDiscovered':
        final args = call.arguments;
        final peerId = args?['peerId'] as String? ?? '';
        final publicKeyDigest = args?['publicKeyDigest'] as Uint8List?;

        if (peerId.isEmpty) return;

        // Call the callback if set
        _onPeerDiscovered?.call(peerId, publicKeyDigest);

        // Add to peer stream
        _peerController?.add({
          'peerId': peerId,
          'publicKeyDigest': publicKeyDigest,
        });
        break;
        
      default:

    }
  }
  
  /// Dispose resources
  void dispose() {
    _messageController?.close();
    _messageController = null;
    _peerController?.close();
    _peerController = null;
    _onPeerDiscovered = null;
    _isInitialized = false;
  }
} 