import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Callback for peer discovery
typedef PeerDiscoveredCallback = void Function(String peerId, Uint8List? publicKeyDigest);

/// BLE Mesh Service for bitchat
/// Implements BLE advertising (peripheral) and scanning (central) functionality
/// Compatible with Swift bitchat implementation
class BluetoothMeshService {
  static final BluetoothMeshService _instance = BluetoothMeshService._internal();
  factory BluetoothMeshService() => _instance;
  BluetoothMeshService._internal();

  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  // Service UUID matching Swift implementation
  static const String serviceUUID = 'F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C';
  static const String characteristicUUID = 'A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D';

  StreamSubscription<ScanResult>? _scanSubscription;
  PeerDiscoveredCallback? onPeerDiscovered;

  bool _isAdvertising = false;
  bool _isScanning = false;
  String? _myPeerID;

  /// Start BLE advertising
  /// Note: Android supports manufacturerData, iOS only supports localName/serviceUuid
  /// Compatible with Swift bitchat implementation
  Future<void> startAdvertising({
    required String peerId,
    Uint8List? publicKeyDigest,
  }) async {
    if (_isAdvertising) return;
    
    _myPeerID = peerId;
    
    // Use same format as Swift: localName = peerID, serviceUUID for discovery
    final advertiseData = AdvertiseData(
      localName: peerId, // Device name for peerId transmission (matches Swift)
      serviceUuid: serviceUUID, // Same UUID as Swift implementation
      manufacturerId: publicKeyDigest != null ? 0xFFFF : null, // Android only
      manufacturerData: publicKeyDigest, // Android only - for additional data
    );
    
    await _blePeripheral.start(advertiseData: advertiseData);
    _isAdvertising = true;
  }

  /// Stop BLE advertising
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
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
      
      Uint8List? publicKeyDigest;
      // Android: manufacturerData may contain custom data
      if (adv.manufacturerData.isNotEmpty) {
        // Take first manufacturerData and convert to Uint8List
        final firstData = adv.manufacturerData.values.first;
        publicKeyDigest = Uint8List.fromList(firstData);
      }
      
      // Filter out our own broadcasts
      if (peerId != null && 
          peerId.isNotEmpty && 
          peerId != _myPeerID && 
          onPeerDiscovered != null) {
        onPeerDiscovered!(peerId, publicKeyDigest);
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

  /// Get current advertising status
  bool get isAdvertising => _isAdvertising;

  /// Get current scanning status  
  bool get isScanning => _isScanning;

  /// Get my peer ID
  String? get myPeerID => _myPeerID;
} 