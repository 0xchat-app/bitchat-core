library bitchat_core;

/// Bitchat core library
/// Provides decentralized Bluetooth mesh chat functionality
/// 
/// This library implements the bitchat protocol for peer-to-peer
/// communication over Bluetooth Low Energy (BLE) mesh networks.

// Core service
export 'src/bitchat_service.dart';

// Models
export 'src/models/bitchat_models.dart';
export 'src/models/peer.dart';
export 'src/models/message.dart';
export 'src/models/channel.dart';

// Protocol
export 'src/protocol/binary_protocol.dart';
export 'src/protocol/bitchat_packet.dart';
export 'src/protocol/message_types.dart';

// Bluetooth
export 'src/bluetooth/bluetooth_mesh_service.dart';

// Encryption
export 'src/encryption/encryption_service.dart';

// Messaging
export 'src/messaging/message_router.dart';
export 'src/messaging/store_and_forward.dart'; 