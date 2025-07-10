import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
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
  final IOSBlePeripheralService _iosService = IOSBlePeripheralService();

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
  final Map<String, List<BluetoothCharacteristic>> _deviceCharacteristics = <String, List<BluetoothCharacteristic>>{};

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
        final iosStarted = await _iosService.startService(
          peerID: peerId,
          nickname: nickname,
        );
        if (iosStarted) {
          print('🔵 iOS BLE peripheral service started');
          
          // Listen for messages from iOS
          _iosService.messageStream.listen((message) {
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
      // Swift expects 8-character peer IDs, so we need to use a 8-char identifier
      final deviceName = peerId.length == 8 ? peerId : peerId.substring(0, 8);
      final advertiseData = AdvertiseData(
        localName: deviceName, // Device name for peerId transmission (matches Swift)
        serviceUuid: serviceUUID, // Same UUID as Swift implementation
        manufacturerId: publicKeyDigest != null ? 0xFFFF : null, // Android only
        manufacturerData: publicKeyDigest, // Android only - for additional data
      );
      
      print('🔵 AdvertiseData created: localName=${advertiseData.localName}, serviceUuid=${advertiseData.serviceUuid}');
      
      await _blePeripheral.start(advertiseData: advertiseData);
      _isAdvertising = true;
      print('🔵 BLE advertising started successfully');
      
      // Start scanning to discover bitchat peers
      startScanning();
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
      await _iosService.stopService();
      print('🔵 iOS BLE peripheral service stopped');
    } catch (e) {
      print('🔵 iOS BLE peripheral service stop failed: $e');
    }
    
    await _blePeripheral.stop();
    _isAdvertising = false;
  }

  /// Start BLE scanning
  /// Uses native iOS implementation when available, fallback to FlutterBluePlus
  Future<void> startScanning({PeerDiscoveredCallback? onPeer}) async {
    if (_isScanning) {
      print('🔵 [BLE] Already scanning, skipping duplicate start');
      return;
    }
    onPeerDiscovered = onPeer;
    
    try {
      print('🔵 [BLE] Starting scan...');

      // Use native iOS scanning if available
      if (Platform.isIOS) {
        try {
          print('🔵 [BLE] Using native iOS scanning');
          final success = await _iosService.startScanning(onPeer: (peerId, publicKeyDigest) {
            print('🔵 [BLE] Native iOS discovered peerId: $peerId');
            
            // Filter out our own broadcasts and ensure peerId is valid
            if (peerId.isNotEmpty && 
                peerId != _myPeerID &&
                peerId.length == 8) {
              print('🔵 [BLE] Calling onPeerDiscovered with peerId: $peerId');
              if (onPeerDiscovered != null) {
                onPeerDiscovered!(peerId, publicKeyDigest);
              }
            } else {
              print('🔵 [BLE] Skipping device: peerId=$peerId (length=${peerId.length}), myPeerID=$_myPeerID');
            }
          });
          
          if (success) {
            _isScanning = true;
            print('🔵 [BLE] Native iOS scanning started successfully');
            return;
          } else {
            print('🔵 [BLE] Native iOS scanning failed, falling back to FlutterBluePlus');
          }
        } catch (e) {
          print('🔵 [BLE] Native iOS scanning not available: $e, falling back to FlutterBluePlus');
        }
      }
      
      // Fallback to FlutterBluePlus scanning for Android or if iOS native fails
      print('🔵 [BLE] Using FlutterBluePlus scanning');
      _scanSubscription = FlutterBluePlus.scan().listen((scanResult) async {
        final adv = scanResult.advertisementData;
        final peerId = adv.localName ?? scanResult.device.name;
        final device = scanResult.device;
        
        print('🔵 [BLE] Discovered device: ${device.platformName}');
        print('🔵 [BLE] Device name: ${scanResult.device.name}');
        print('🔵 [BLE] Advertisement localName: ${adv.localName}');
        print('🔵 [BLE] Advertisement serviceUUIDs: ${adv.serviceUuids}');
        print('🔵 [BLE] Advertisement manufacturerData: ${adv.manufacturerData}');
        print('🔵 [BLE] Using peerId: $peerId');
        print('🔵 [BLE] My peerId: $_myPeerID');
        
        // Check if device has our service UUID
        final hasServiceUUID = adv.serviceUuids.any((uuid) => 
          uuid.toString().toUpperCase() == serviceUUID.toUpperCase()
        );
        
        if (!hasServiceUUID) {
          print('🔵 [BLE] Skipping device: does not have our service UUID');
          return;
        }
        
        Uint8List? publicKeyDigest;
        if (adv.manufacturerData.isNotEmpty) {
          final firstData = adv.manufacturerData.values.first;
          publicKeyDigest = Uint8List.fromList(firstData);
          print('🔵 [BLE] Found manufacturer data: ${firstData.length} bytes');
        }
        
        // Filter out our own broadcasts and ensure peerId is valid
        if (peerId != null && 
            peerId.isNotEmpty && 
            peerId != _myPeerID &&
            peerId.length == 8) { // Swift only connects to 8-char peer IDs
          print('🔵 [BLE] Calling onPeerDiscovered with peerId: $peerId');
          if (onPeerDiscovered != null) {
            onPeerDiscovered!(peerId, publicKeyDigest);
          }
          // Auto connect to discovered peer
          await _connectToPeer(peerId, device);
        } else {
          print('🔵 [BLE] Skipping device: peerId=$peerId (length=${peerId?.length}), myPeerID=$_myPeerID, onPeerDiscovered=${onPeerDiscovered != null}');
          if (peerId == null) {
            print('🔵 [BLE] peerId is null');
          } else if (peerId.isEmpty) {
            print('🔵 [BLE] peerId is empty');
          } else if (peerId == _myPeerID) {
            print('🔵 [BLE] peerId matches my own peer ID');
          } else if (peerId.length != 8) {
            print('🔵 [BLE] peerId length is not 8: ${peerId.length}');
          }
        }
      });
      _isScanning = true;
      print('🔵 [BLE] FlutterBluePlus scanning started successfully');
    } catch (e) {
      print('🔴 [BLE] Failed to start scanning: $e');
      print('🔴 [BLE] Error type: ${e.runtimeType}');
      // Don't set _isScanning to true if scanning failed
    }
  }

  /// Stop BLE scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    
    // Stop native iOS scanning if active
    if (Platform.isIOS) {
      try {
        await _iosService.stopScanning();
        print('🔵 [BLE] Native iOS scanning stopped');
      } catch (e) {
        print('🔵 [BLE] Error stopping native iOS scanning: $e');
      }
    }
    
    // Stop FlutterBluePlus scanning if active
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    print('🔵 [BLE] Scanning stopped');
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
  
  /// Connect to a discovered peer and subscribe to notify
  Future<void> _connectToPeer(String peerId, BluetoothDevice device) async {
    if (_connectedDevices.contains(peerId)) {
      print('🔵 Already connected to peer: $peerId');
      return;
    }
    try {
      print('🔵 Connecting to peer: $peerId (${device.platformName})');
      print('🔵 Device ID: ${device.remoteId}');
      print('🔵 Device name: ${device.platformName}');
      await device.connect(autoConnect: false);
      print('🔵 Connected to peer: $peerId');
      final services = await device.discoverServices();
      print('🔵 Discovered ${services.length} services for peer: $peerId');
      for (final service in services) {
        print('🔵 Service UUID: ${service.uuid}');
        if (service.uuid.toString().toUpperCase() == serviceUUID.toUpperCase()) {
          print('🔵 Found bitchat service for peer: $peerId');
          print('🔵 Service has ${service.characteristics.length} characteristics');
          for (final characteristic in service.characteristics) {
            print('🔵 Characteristic UUID: ${characteristic.uuid}');
            if (characteristic.uuid.toString().toUpperCase() == characteristicUUID.toUpperCase()) {
              print('🔵 Found bitchat characteristic for peer: $peerId');
              print('🔵 Characteristic properties: ${characteristic.properties}');
              await characteristic.setNotifyValue(true);
              print('🔵 Subscribed to notifications from peer: $peerId');
              // Listen for notifications
              characteristic.lastValueStream.listen((value) {
                print('🔵 Received notification from peer $peerId: ${value.length} bytes');
                if (onMessageReceived != null) {
                  onMessageReceived!(peerId, Uint8List.fromList(value));
                }
              });
              _deviceCharacteristics[peerId] = [characteristic];
              break;
            }
          }
          break;
        }
      }
      _connectedDevices.add(peerId);
      _connectedPeripherals[peerId] = device;
      print('🔵 Successfully connected to peer: $peerId');
    } catch (e) {
      print('🔴 Failed to connect to peer $peerId: $e');
    }
  }
  
  /// Send message via BLE
  Future<bool> sendMessage(Uint8List data) async {
    try {
      print('🔵 Sending message via BLE: ${data.length} bytes');
      
      // Send via iOS peripheral service if available
      try {
        final success = await _iosService.sendMessage(data);
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
      
      // Send to connected peripherals
      var sentToPeripherals = 0;
      for (final entry in _deviceCharacteristics.entries) {
        final peerId = entry.key;
        final characteristics = entry.value;
        
        for (final characteristic in characteristics) {
          try {
            await characteristic.write(data, withoutResponse: true);
            sentToPeripherals++;
            print('🔵 Message sent to peripheral: $peerId');
          } catch (e) {
            print('🔴 Failed to send message to peripheral $peerId: $e');
          }
        }
      }
      
      if (sentToPeripherals > 0) {
        print('🔵 Message sent to $sentToPeripherals peripherals');
        return true;
      }
      
      print('🔴 No BLE service available for sending message');
      return false;
    } catch (e) {
      print('🔴 Failed to send message via BLE: $e');
      return false;
    }
  }
} 