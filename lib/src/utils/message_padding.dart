/// Message padding utilities for bitchat
/// Implements PKCS#7 padding compatible with Swift version
import 'dart:typed_data';
import 'dart:math';

/// Message padding utilities compatible with Swift bitchat
class MessagePadding {
  /// Standard block sizes for padding (same as Swift)
  static const List<int> blockSizes = [256, 512, 1024, 2048];
  
  /// Add PKCS#7-style padding to reach target size
  /// Same logic as Swift implementation
  static Uint8List pad(Uint8List data, int targetSize) {
    if (data.length >= targetSize) {
      return data; // No padding needed
    }
    
    final paddingNeeded = targetSize - data.length;
    
    // PKCS#7 only supports padding up to 255 bytes
    // If we need more padding than that, don't pad - return original data
    if (paddingNeeded > 255) {
      return data;
    }
    
    final padded = Uint8List(targetSize);
    padded.setRange(0, data.length, data);
    
    // Add random bytes for padding (except last byte)
    final random = Random.secure();
    for (int i = data.length; i < targetSize - 1; i++) {
      padded[i] = random.nextInt(256);
    }
    
    // Last byte contains the padding length
    padded[targetSize - 1] = paddingNeeded;
    
    return padded;
  }
  
  /// Remove padding from data
  /// Same logic as Swift implementation
  static Uint8List unpad(Uint8List data) {
    if (data.isEmpty) {
      return data;
    }
    
    // Last byte tells us how much padding to remove
    final paddingLength = data[data.length - 1];
    
    if (paddingLength <= 0 || paddingLength > data.length) {
      return data; // Invalid padding, return original
    }
    
    return data.sublist(0, data.length - paddingLength);
  }
  
  /// Find optimal block size for data
  /// Same logic as Swift implementation
  static int optimalBlockSize(int dataLength) {
    for (final blockSize in blockSizes) {
      if (dataLength < blockSize) {
        return blockSize;
      }
    }
    
    // If data is larger than all block sizes, don't pad
    return dataLength;
  }
  
  /// Check if data needs padding
  static bool needsPadding(int dataLength) {
    return dataLength < blockSizes.last;
  }
  
  /// Get padding size for given data length
  static int getPaddingSize(int dataLength) {
    final targetSize = optimalBlockSize(dataLength);
    return targetSize - dataLength;
  }
} 