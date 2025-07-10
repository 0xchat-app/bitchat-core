import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'ios_ble_peripheral.dart';

/// Callback for peer discovery
typedef PeerDiscoveredCallback = void Function(String peerId, Uint8List? publicKeyDigest);

/// Callback for received messages
typedef MessageReceivedCallback = void Function(String senderId, Uint8List data);

/// BLE Mesh Service for bitchat
/// Implements BLE advertising (peripheral) and scanning (central) functionality
/// Compatible with Swift bitchat implementation
class BluetoothMeshService {
  static final BluetoothMeshService _instance = BluetoothMeshService._internal();
  factory BluetoothMeshService() => _instance;
  BluetoothMeshService._internal();

  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();
  final IOSBlePeripheralService _iosPeripheral = IOSBlePeripheralService();

  // Service UUID matching Swift implementation
  static const String serviceUUID = 'F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C';
  static const String characteristicUUID = 'A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D';

  StreamSubscription<ScanResult>? _scanSubscription;
  PeerDiscoveredCallback? onPeerDiscovered;
  MessageReceivedCallback? onMessageReceived;

  bool _isAdvertising = false;
  bool _isScanning = false;
  String? _myPeerID;
  String? _myNickname;

  // Connected devices tracking
  final Set<String> _connectedDevices = <String>{};
  final Map<String, BluetoothDevice> _connectedPeripherals = <String, BluetoothDevice>{};

  /// Start BLE advertising with peripheral service
  /// Note: Android supports manufacturerData, iOS only supports localName/serviceUuid
  /// Compatible with Swift bitchat implementation
  Future<void> startAdvertising({
    required String peerId,
    required String nickname,
    Uint8List? publicKeyDigest,
  }) async {
    if (_isAdvertising) return;
    
    _myPeerID = peerId;
    _myNickname = nickname;
    
    try {
      print('🔵 Starting BLE advertising with peerId: $peerId');
      print('🔵 Public key digest length: ${publicKeyDigest?.length ?? 0}');
      
      // Start iOS peripheral service
      try {
        final iosStarted = await _iosPeripheral.startService(
          peerID: peerId,
          nickname: nickname,
        );
        if (iosStarted) {
          print('🔵 iOS BLE peripheral service started');
          
          // Listen for messages from iOS
          _iosPeripheral.messageStream.listen((message) {
            final senderId = message['senderId'] as String;
            final payload = message['payload'] as Uint8List;
            print('🔵 Received message from iOS: senderId=$senderId, payload=${payload.length} bytes');
            
            if (onMessageReceived != null) {
              onMessageReceived!(senderId, payload);
            }
          });
        } else {
          print('🔵 iOS BLE peripheral service not available');
        }
      } catch (e) {
        print('🔵 iOS BLE peripheral service not available: $e');
      }
      
      // Start Android foreground service for persistent advertising
      try {
        const platform = MethodChannel('com.oxchat.lite/ble_service');
        await platform.invokeMethod('startBleService');
        print('🔵 Android BLE service started');
      } catch (e) {
        print('🔵 Android BLE service not available: $e');
      }
      
      // Wait for BLE peripheral to be ready (especially important for iOS)
      bool isReady = false;
      int attempts = 0;
      while (!isReady && attempts < 10) {
        try {
          // Check if BLE is supported and ready
          isReady = await _blePeripheral.isSupported;
          if (!isReady) {
            print('🔵 Waiting for BLE peripheral to be ready... (attempt ${attempts + 1})');
            await Future.delayed(Duration(milliseconds: 500));
            attempts++;
          }
        } catch (e) {
          print('🔵 BLE peripheral not ready: $e');
          await Future.delayed(Duration(milliseconds: 500));
          attempts++;
        }
      }
      
      if (!isReady) {
        print('🔴 BLE peripheral not ready after multiple attempts, continuing anyway...');
      }
      
      // Use same format as Swift: localName = peerID, serviceUUID for discovery
      final advertiseData = AdvertiseData(
        localName: peerId, // Device name for peerId transmission (matches Swift)
        serviceUuid: serviceUUID, // Same UUID as Swift implementation
        manufacturerId: publicKeyDigest != null ? 0xFFFF : null, // Android only
        manufacturerData: publicKeyDigest, // Android only - for additional data
      );
      
      print('🔵 AdvertiseData created: localName=${advertiseData.localName}, serviceUuid=${advertiseData.serviceUuid}');
      
      await _blePeripheral.start(advertiseData: advertiseData);
      _isAdvertising = true;
      print('🔵 BLE advertising started successfully');
      
      // Start scanning to discover bitchat peers
      startScanning(onPeer: (peerId, publicKeyDigest) {
        print('🔵 Discovered bitchat peer: $peerId');
        // Add to connected devices for now (simplified)
        _connectedDevices.add(peerId);
      });
    } catch (e) {
      print('🔴 BLE advertising failed: $e');
      print('🔴 Error type: ${e.runtimeType}');
      rethrow;
    }
  }



  /// Stop BLE advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    // Stop iOS peripheral service
    try {
      await _iosPeripheral.stopService();
      print('🔵 iOS BLE peripheral service stopped');
    } catch (e) {
      print('🔵 iOS BLE peripheral service stop failed: $e');
    }
    
    await _blePeripheral.stop();
    _isAdvertising = false;
  }

  /// Start BLE scanning
  /// Scans for devices with matching service UUID (same as Swift)
  Future<void> startScanning({PeerDiscoveredCallback? onPeer}) async {
    if (_isScanning) return;
    onPeerDiscovered = onPeer;
    
    // Scan for devices with matching service UUID (same as Swift implementation)
    _scanSubscription = FlutterBluePlus.scan().listen((scanResult) {
      final adv = scanResult.advertisementData;
      final peerId = adv.localName ?? scanResult.device.name;
      
      print('🔵 [BLE] Discovered device: ${scanResult.device.name}');
      print('🔵 [BLE] Advertisement localName: ${adv.localName}');
      print('🔵 [BLE] Advertisement manufacturerData: ${adv.manufacturerData}');
      print('🔵 [BLE] Using peerId: $peerId');
      
      Uint8List? publicKeyDigest;
      // Android: manufacturerData may contain custom data
      if (adv.manufacturerData.isNotEmpty) {
        // Take first manufacturerData and convert to Uint8List
        final firstData = adv.manufacturerData.values.first;
        publicKeyDigest = Uint8List.fromList(firstData);
        print('🔵 [BLE] Found manufacturer data: ${firstData.length} bytes');
      }
      
      // Filter out our own broadcasts
      if (peerId != null && 
          peerId.isNotEmpty && 
          peerId != _myPeerID && 
          onPeerDiscovered != null) {
        print('🔵 [BLE] Calling onPeerDiscovered with peerId: $peerId');
        onPeerDiscovered!(peerId, publicKeyDigest);
      } else {
        print('🔵 [BLE] Skipping device: peerId=$peerId, myPeerID=$_myPeerID, onPeerDiscovered=${onPeerDiscovered != null}');
      }
    });
    
    _isScanning = true;
  }

  /// Stop BLE scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    await _scanSubscription?.cancel();
    _isScanning = false;
  }



  /// Set message received callback
  void setMessageReceivedCallback(MessageReceivedCallback callback) {
    onMessageReceived = callback;
  }

  /// Get current advertising status
  bool get isAdvertising => _isAdvertising;

  /// Get current scanning status  
  bool get isScanning => _isScanning;

  /// Get my peer ID
  String? get myPeerID => _myPeerID;

  /// Get connected devices count
  int get connectedDevicesCount => _connectedDevices.length;
  
  /// Send message via BLE
  Future<bool> sendMessage(Uint8List data) async {
    try {
      print('🔵 Sending message via BLE: ${data.length} bytes');
      
      // Send via iOS peripheral service if available
      try {
        final success = await _iosPeripheral.sendMessage(data);
        if (success) {
          print('🔵 Message sent via iOS peripheral service');
          return true;
        }
      } catch (e) {
        print('🔵 iOS peripheral service not available: $e');
      }
      
      // Send via Android BLE service if available
      try {
        const platform = MethodChannel('com.oxchat.lite/ble_service');
        final result = await platform.invokeMethod('sendMessage', {'data': data});
        if (result == true) {
          print('🔵 Message sent via Android BLE service');
          return true;
        }
      } catch (e) {
        print('🔵 Android BLE service not available: $e');
      }
      
      print('🔴 No BLE service available for sending message');
      return false;
    } catch (e) {
      print('🔴 Failed to send message via BLE: $e');
      return false;
    }
  }
} 