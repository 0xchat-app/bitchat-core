/// Binary protocol implementation for bitchat
/// 
/// This implements the compact binary protocol used for BLE communication
/// with the following format:
/// 
/// Header (Fixed 13 bytes):
/// - Version: 1 byte
/// - Type: 1 byte  
/// - TTL: 1 byte
/// - Timestamp: 8 bytes (UInt64)
/// - Flags: 1 byte (bit 0: hasRecipient, bit 1: hasSignature)
/// - PayloadLength: 2 bytes (UInt16)
/// 
/// Variable sections:
/// - SenderID: 8 bytes (fixed)
/// - RecipientID: 8 bytes (if hasRecipient flag set)
/// - Payload: Variable length
/// - Signature: 64 bytes (if hasSignature flag set)

import 'dart:typed_data';
import 'bitchat_packet.dart';
import '../utils/compression_util.dart';

class BinaryProtocol {
  static const int headerSize = 13;
  static const int senderIDSize = 8;
  static const int recipientIDSize = 8;
  static const int signatureSize = 64;
  
  static const int version = 1;
  
  // Flags
  static const int hasRecipient = 0x01;
  static const int hasSignature = 0x02;
  static const int isCompressed = 0x04;
  
  /// Encode BitchatPacket to binary format
  static Uint8List? encode(BitchatPacket packet) {
    try {
      final List<int> data = [];
      
      // Try to compress payload if beneficial
      Uint8List payload = packet.payload;
      int? originalPayloadSize;
      bool isCompressed = false;
      
      if (CompressionUtil.shouldCompress(payload)) {
        final compressedPayload = CompressionUtil.compress(payload);
        if (compressedPayload != null) {
          originalPayloadSize = payload.length;
          payload = compressedPayload;
          isCompressed = true;
        }
      }
      
      // Header
      data.add(packet.version);
      data.add(packet.type);
      data.add(packet.ttl);
      
      // Timestamp (8 bytes, big-endian)
      final timestampBytes = _int64ToBytes(packet.timestamp);
      data.addAll(timestampBytes);
      
      // Flags
      int flags = 0;
      if (packet.recipientID != null) {
        flags |= hasRecipient;
      }
      if (packet.signature != null) {
        flags |= hasSignature;
      }
      if (isCompressed) {
        flags |= BinaryProtocol.isCompressed;
      }
      data.add(flags);
      
      // Payload length (2 bytes, big-endian) - includes original size if compressed
      final payloadDataSize = payload.length + (isCompressed ? 2 : 0);
      final payloadLengthBytes = _int16ToBytes(payloadDataSize);
      data.addAll(payloadLengthBytes);
      
      // SenderID (exactly 8 bytes)
      final senderBytes = _padToSize(packet.senderID, senderIDSize);
      data.addAll(senderBytes);
      
      // RecipientID (if present)
      if (packet.recipientID != null) {
        final recipientBytes = _padToSize(packet.recipientID!, recipientIDSize);
        data.addAll(recipientBytes);
      }
      
      // Payload (with original size prepended if compressed)
      if (isCompressed && originalPayloadSize != null) {
        // Prepend original size (2 bytes, big-endian)
        final originalSizeBytes = _int16ToBytes(originalPayloadSize);
        data.addAll(originalSizeBytes);
      }
      data.addAll(payload);
      
      // Signature (if present)
      if (packet.signature != null) {
        final signatureBytes = _padToSize(packet.signature!, signatureSize);
        data.addAll(signatureBytes);
      }
      
      return Uint8List.fromList(data);
    } catch (e) {
      print('Error encoding packet: $e');
      return null;
    }
  }
  
  /// Decode binary data to BitchatPacket
  static BitchatPacket? decode(Uint8List data) {
    try {
      if (data.length < headerSize + senderIDSize) {
        return null;
      }
      
      int offset = 0;
      
      // Header
      final version = data[offset]; offset++;
      // Only support version 1
      if (version != 1) return null;
      
      final type = data[offset]; offset++;
      final ttl = data[offset]; offset++;
      
      // Timestamp
      final timestampBytes = data.sublist(offset, offset + 8);
      final timestamp = _bytesToInt64(timestampBytes);
      offset += 8;
      
      // Flags
      final flags = data[offset]; offset++;
      final hasRecipientFlag = (flags & hasRecipient) != 0;
      final hasSignatureFlag = (flags & hasSignature) != 0;
      final isCompressedFlag = (flags & isCompressed) != 0;
      
      // Payload length
      final payloadLengthBytes = data.sublist(offset, offset + 2);
      final payloadLength = _bytesToInt16(payloadLengthBytes);
      offset += 2;
      
      // Calculate expected total size
      int expectedSize = headerSize + senderIDSize + payloadLength;
      if (hasRecipientFlag) {
        expectedSize += recipientIDSize;
      }
      if (hasSignatureFlag) {
        expectedSize += signatureSize;
      }
      
      if (data.length < expectedSize) {
        return null;
      }
      
      // SenderID
      final senderID = data.sublist(offset, offset + senderIDSize);
      offset += senderIDSize;
      
      // RecipientID
      Uint8List? recipientID;
      if (hasRecipientFlag) {
        recipientID = data.sublist(offset, offset + recipientIDSize);
        offset += recipientIDSize;
      }
      
      // Payload
      Uint8List payload;
      if (isCompressedFlag) {
        // First 2 bytes are original size
        if (payloadLength < 2) return null;
        final originalSizeBytes = data.sublist(offset, offset + 2);
        final originalSize = _bytesToInt16(originalSizeBytes);
        offset += 2;
        
        // Compressed payload
        final compressedPayload = data.sublist(offset, offset + payloadLength - 2);
        offset += payloadLength - 2;
        
        // Decompress
        final decompressedPayload = CompressionUtil.decompress(compressedPayload, originalSize: originalSize);
        if (decompressedPayload == null) {
          return null;
        }
        payload = decompressedPayload;
      } else {
        payload = data.sublist(offset, offset + payloadLength);
        offset += payloadLength;
      }
      
      // Signature
      Uint8List? signature;
      if (hasSignatureFlag) {
        signature = data.sublist(offset, offset + signatureSize);
      }
      
      return BitchatPacket(
        version: version,
        type: type,
        ttl: ttl,
        timestamp: timestamp,
        senderID: senderID,
        recipientID: recipientID,
        payload: payload,
        signature: signature,
      );
    } catch (e) {
      print('Error decoding packet: $e');
      return null;
    }
  }
  
  // Utility methods for byte conversion
  static Uint8List _int64ToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = (value & 0xFF);
      value >>= 8;
    }
    return bytes;
  }
  
  static int _bytesToInt64(Uint8List bytes) {
    int result = 0;
    for (int i = 0; i < 8; i++) {
      result = (result << 8) | bytes[i];
    }
    return result;
  }
  
  static Uint8List _int16ToBytes(int value) {
    return Uint8List.fromList([
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }
  
  static int _bytesToInt16(Uint8List bytes) {
    return (bytes[0] << 8) | bytes[1];
  }
  
  static Uint8List _padToSize(Uint8List data, int size) {
    if (data.length >= size) {
      return data.sublist(0, size);
    } else {
      final padded = Uint8List(size);
      padded.setRange(0, data.length, data);
      return padded;
    }
  }
} 