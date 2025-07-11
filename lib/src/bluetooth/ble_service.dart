import 'dart:async';
import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback for peer discovery
typedef PeerDiscoveredCallback = void Function(String peerId, Uint8List? publicKeyDigest);

/// Callback for received messages
typedef MessageReceivedCallback = void Function(String senderId, Uint8List data);

/// BLE Service for bitchat using bluetooth_low_energy library
/// Provides both central and peripheral functionality
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Service and characteristic UUIDs
  static const String serviceUUID = 'F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C';
  static const String characteristicUUID = 'A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D';

  // Stream controllers
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _peerController = 
      StreamController<Map<String, dynamic>>.broadcast();

  // State management
  bool _isInitialized = false;
  bool _isAdvertising = false;
  bool _isScanning = false;
  String? _myPeerID;
  String? _myNickname;

  // Callbacks
  PeerDiscoveredCallback? onPeerDiscovered;
  MessageReceivedCallback? onMessageReceived;

  // Managers
  late CentralManager _centralManager;
  late PeripheralManager _peripheralManager;

  // Connected devices tracking
  final Map<String, Peripheral> _connectedDevices = <String, Peripheral>{};
  final Map<String, GATTCharacteristic> _deviceCharacteristics = 
      <String, GATTCharacteristic>{};

  // Stream subscriptions
  StreamSubscription? _discoveredSubscription;
  StreamSubscription? _characteristicNotifiedSubscription;
  StreamSubscription? _characteristicWriteRequestedSubscription;
  StreamSubscription? _connectionStateChangedSubscription;

  /// Initialize the BLE service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request permissions
      final bluetoothPermission = await Permission.bluetooth.request();
      final bluetoothScanPermission = await Permission.bluetoothScan.request();
      final bluetoothConnectPermission = await Permission.bluetoothConnect.request();
      final bluetoothAdvertisePermission = await Permission.bluetoothAdvertise.request();

      if (bluetoothPermission.isDenied || 
          bluetoothScanPermission.isDenied || 
          bluetoothConnectPermission.isDenied || 
          bluetoothAdvertisePermission.isDenied) {
        print('Bluetooth permissions denied');
        return false;
      }

      // Initialize managers
      _centralManager = CentralManager();
      _peripheralManager = PeripheralManager();

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;
      print('BLE Service initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize BLE service: $e');
      return false;
    }
  }

  /// Set up event listeners
  void _setupEventListeners() {
    // Listen for discovered peripherals
    _discoveredSubscription = _centralManager.discovered.listen((event) {
      _handleDiscoveredPeripheral(event);
    });

    // Listen for characteristic notifications
    _characteristicNotifiedSubscription = _centralManager.characteristicNotified.listen((event) {
      _handleCharacteristicNotification(event);
    });

    // Listen for characteristic write requests (peripheral mode)
    _characteristicWriteRequestedSubscription = _peripheralManager.characteristicWriteRequested.listen((event) {
      _handleCharacteristicWriteRequest(event);
    });

    // Listen for connection state changes
    _connectionStateChangedSubscription = _centralManager.connectionStateChanged.listen((event) {
      _handleConnectionStateChanged(event);
    });
  }

  /// Start BLE advertising (peripheral mode)
  Future<bool> startAdvertising({
    required String peerId,
    required String nickname,
    Uint8List? publicKeyDigest,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isAdvertising) return true;

    try {
      _myPeerID = peerId;
      _myNickname = nickname;

      // Remove any existing services
      await _peripheralManager.removeAllServices();

      // Create service
      final service = GATTService(
        uuid: UUID.fromString(serviceUUID),
        isPrimary: true,
        includedServices: [],
        characteristics: [
          GATTCharacteristic.mutable(
            uuid: UUID.fromString(characteristicUUID),
            properties: [
              GATTCharacteristicProperty.read,
              GATTCharacteristicProperty.write,
              GATTCharacteristicProperty.writeWithoutResponse,
              GATTCharacteristicProperty.notify,
            ],
            permissions: [
              GATTCharacteristicPermission.read,
              GATTCharacteristicPermission.write,
            ],
            descriptors: [],
          ),
        ],
      );

      // Add service to peripheral manager
      await _peripheralManager.addService(service);

      // Create advertisement
      final advertisement = Advertisement(
        name: peerId.length == 8 ? peerId : peerId.substring(0, 8),
        serviceUUIDs: [UUID.fromString(serviceUUID)],
        manufacturerSpecificData: publicKeyDigest != null 
            ? [
                ManufacturerSpecificData(
                  id: 0xFFFF,
                  data: publicKeyDigest,
                )
              ]
            : [],
      );

      // Start advertising
      await _peripheralManager.startAdvertising(advertisement);
      _isAdvertising = true;
      
      print('BLE advertising started for peer: $peerId');
      
      // Start scanning to discover other peers
      await startScanning();
      
      return true;
    } catch (e) {
      print('Failed to start advertising: $e');
      return false;
    }
  }

  /// Stop BLE advertising
  Future<bool> stopAdvertising() async {
    if (!_isAdvertising) return true;

    try {
      await _peripheralManager.stopAdvertising();
      await stopScanning();
      _isAdvertising = false;
      print('BLE advertising stopped');
      return true;
    } catch (e) {
      print('Failed to stop advertising: $e');
      return false;
    }
  }

  /// Start BLE scanning (central mode)
  Future<bool> startScanning({PeerDiscoveredCallback? onPeer}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_isScanning) return true;

    onPeerDiscovered = onPeer;

    try {
      await _centralManager.startDiscovery(
        serviceUUIDs: [UUID.fromString(serviceUUID)],
      );
      _isScanning = true;
      print('BLE scanning started');
      return true;
    } catch (e) {
      print('Failed to start scanning: $e');
      return false;
    }
  }

  /// Stop BLE scanning
  Future<bool> stopScanning() async {
    if (!_isScanning) return true;

    try {
      await _centralManager.stopDiscovery();
      _isScanning = false;
      print('BLE scanning stopped');
      return true;
    } catch (e) {
      print('Failed to stop scanning: $e');
      return false;
    }
  }

  /// Handle discovered peripheral
  void _handleDiscoveredPeripheral(DiscoveredEventArgs event) {
    try {
      final peripheral = event.peripheral;
      final advertisement = event.advertisement;

      // Extract peer ID from advertisement name
      final peerId = advertisement.name;
      if (peerId == null || peerId.isEmpty || peerId == _myPeerID) return;

      // Extract public key digest from manufacturer data
      Uint8List? publicKeyDigest;
      if (advertisement.manufacturerSpecificData.isNotEmpty) {
        publicKeyDigest = advertisement.manufacturerSpecificData.first.data;
      }

      print('Discovered peer: $peerId');

      // Call callback
      onPeerDiscovered?.call(peerId, publicKeyDigest);

      // Add to peer stream
      _peerController.add({
        'peerId': peerId,
        'publicKeyDigest': publicKeyDigest,
        'peripheral': peripheral,
        'rssi': event.rssi,
      });

      // Auto connect to discovered peer
      _connectToPeer(peerId, peripheral);
    } catch (e) {
      print('Error handling discovered peripheral: $e');
    }
  }

  /// Connect to a discovered peer
  Future<void> _connectToPeer(String peerId, Peripheral peripheral) async {
    if (_connectedDevices.containsKey(peerId)) return;

    try {
      print('Connecting to peer: $peerId');
      
      // Connect to peripheral
      await _centralManager.connect(peripheral);
      _connectedDevices[peerId] = peripheral;

      // Discover GATT services
      final services = await _centralManager.discoverGATT(peripheral);
      final targetService = services.firstWhere(
        (service) => service.uuid.toString().toUpperCase() == serviceUUID.toUpperCase(),
        orElse: () => throw Exception('Service not found'),
      );

      final characteristic = targetService.characteristics.firstWhere(
        (char) => char.uuid.toString().toUpperCase() == characteristicUUID.toUpperCase(),
        orElse: () => throw Exception('Characteristic not found'),
      );

      _deviceCharacteristics[peerId] = characteristic;

      // Enable notifications
      await _centralManager.setCharacteristicNotifyState(
        peripheral,
        characteristic,
        state: true,
      );

      print('Connected to peer: $peerId');
    } catch (e) {
      print('Failed to connect to peer $peerId: $e');
    }
  }

  /// Handle characteristic notification
  void _handleCharacteristicNotification(GATTCharacteristicNotifiedEventArgs event) {
    try {
      // Find peer ID by peripheral
      String? peerId;
      for (final entry in _connectedDevices.entries) {
        if (entry.value == event.peripheral) {
          peerId = entry.key;
          break;
        }
      }

      if (peerId != null) {
        print('Received notification from peer: $peerId');
        _handleReceivedMessage(peerId, event.value);
      }
    } catch (e) {
      print('Error handling characteristic notification: $e');
    }
  }

  /// Handle characteristic write request (peripheral mode)
  void _handleCharacteristicWriteRequest(GATTCharacteristicWriteRequestedEventArgs event) async {
    try {
      final data = event.request.value;
      final central = event.central;
      
      // Find peer ID by central (this is a simplified approach)
      // In a real implementation, you'd need to track central connections
      final peerId = 'central-${central.uuid}';
      
      print('Received write request from central: ${central.uuid}');
      _handleReceivedMessage(peerId, data);
      
      // Respond to the write request
      await _peripheralManager.respondWriteRequest(event.request);
    } catch (e) {
      print('Error handling characteristic write request: $e');
    }
  }

  /// Handle connection state changes
  void _handleConnectionStateChanged(PeripheralConnectionStateChangedEventArgs event) {
    try {
      final peripheral = event.peripheral;
      final state = event.state;
      
      // Find peer ID by peripheral
      String? peerId;
      for (final entry in _connectedDevices.entries) {
        if (entry.value == peripheral) {
          peerId = entry.key;
          break;
        }
      }

      if (peerId != null) {
        print('Connection state changed for peer $peerId: $state');
        
        if (state == ConnectionState.disconnected) {
          _connectedDevices.remove(peerId);
          _deviceCharacteristics.remove(peerId);
        }
      }
    } catch (e) {
      print('Error handling connection state change: $e');
    }
  }

  /// Handle received messages
  void _handleReceivedMessage(String senderId, Uint8List data) {
    print('Handling received message from $senderId, length: ${data.length}');
    
    // Call callback
    onMessageReceived?.call(senderId, data);

    // Add to message stream
    _messageController.add({
      'senderId': senderId,
      'payload': data,
    });
  }

  /// Set message received callback
  void setMessageReceivedCallback(MessageReceivedCallback callback) {
    onMessageReceived = callback;
  }

  /// Send message to a specific peer
  Future<bool> sendMessage(String peerId, Uint8List data) async {
    try {
      final characteristic = _deviceCharacteristics[peerId];
      if (characteristic == null) {
        print('No characteristic found for peer: $peerId');
        return false;
      }

      final peripheral = _connectedDevices[peerId];
      if (peripheral == null) {
        print('No peripheral found for peer: $peerId');
        return false;
      }

      print('Sending message to peer: $peerId, length: ${data.length}');
      
      await _centralManager.writeCharacteristic(
        peripheral,
        characteristic,
        value: data,
        type: GATTCharacteristicWriteType.withResponse,
      );
      
      print('Message sent successfully to peer: $peerId');
      return true;
    } catch (e) {
      print('Failed to send message to peer $peerId: $e');
      return false;
    }
  }

  /// Send broadcast message to all connected peers
  Future<bool> sendBroadcastMessage(Uint8List data) async {
    print('Sending broadcast message to ${_connectedDevices.length} peers');
    
    bool success = true;
    for (final peerId in _connectedDevices.keys) {
      final result = await sendMessage(peerId, data);
      if (!result) success = false;
    }
    
    if (success) {
      print('Broadcast message sent successfully');
    } else {
      print('Some broadcast messages failed to send');
    }
    
    return success;
  }

  /// Get message stream
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Get peer discovery stream
  Stream<Map<String, dynamic>> get peerStream => _peerController.stream;

  /// Check if currently advertising
  bool get isAdvertising => _isAdvertising;

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Get connected devices
  Set<String> get connectedPeers => _connectedDevices.keys.toSet();

  /// Disconnect from a peer
  Future<void> disconnectPeer(String peerId) async {
    try {
      final peripheral = _connectedDevices[peerId];
      if (peripheral != null) {
        await _centralManager.disconnect(peripheral);
        _connectedDevices.remove(peerId);
        _deviceCharacteristics.remove(peerId);
        print('Disconnected from peer: $peerId');
      }
    } catch (e) {
      print('Failed to disconnect from peer $peerId: $e');
    }
  }

  /// Disconnect from all peers
  Future<void> disconnectAllPeers() async {
    print('Disconnecting from all peers');
    for (final peerId in _connectedDevices.keys.toList()) {
      await disconnectPeer(peerId);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    print('Disposing BLE service');
    
    await stopAdvertising();
    await stopScanning();
    await disconnectAllPeers();
    
    await _discoveredSubscription?.cancel();
    await _characteristicNotifiedSubscription?.cancel();
    await _characteristicWriteRequestedSubscription?.cancel();
    await _connectionStateChangedSubscription?.cancel();
    
    await _messageController.close();
    await _peerController.close();
    
    print('BLE service disposed');
  }
} 