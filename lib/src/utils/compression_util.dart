/// Compression utilities for bitchat messages
/// 
/// Implements LZ4-like compression for message payloads to reduce
/// bandwidth usage and improve transmission efficiency.
import 'dart:typed_data';
import 'dart:math';

class CompressionUtil {
  /// Minimum size for compression to be beneficial
  static const int minCompressSize = 100;
  
  /// Maximum compression ratio to consider compression beneficial
  static const double minCompressionRatio = 0.8;
  
  /// Check if data should be compressed
  static bool shouldCompress(Uint8List data) {
    if (data.length < minCompressSize) return false;
    
    // Check if data is already compressed (look for common compressed patterns)
    if (_isAlreadyCompressed(data)) return false;
    
    return true;
  }
  
  /// Compress data using LZ4-like algorithm
  static Uint8List? compress(Uint8List data) {
    try {
      if (data.length < minCompressSize) return null;
      
      final compressed = _lz4Compress(data);
      final ratio = compressed.length / data.length;
      
      // Only return compressed data if it's actually smaller
      if (ratio >= minCompressionRatio) return null;
      
      return compressed;
    } catch (e) {
      print('Compression error: $e');
      return null;
    }
  }
  
  /// Decompress data
  static Uint8List? decompress(Uint8List compressedData, {required int originalSize}) {
    try {
      return _lz4Decompress(compressedData, originalSize);
    } catch (e) {
      print('Decompression error: $e');
      return null;
    }
  }
  
  /// Check if data appears to be already compressed
  static bool _isAlreadyCompressed(Uint8List data) {
    // Simple heuristic: check for repeated patterns and byte distribution
    if (data.length < 10) return false;
    
    // Check for common compression headers
    if (data.length >= 2) {
      if (data[0] == 0x1F && data[1] == 0x8B) return true; // gzip
      if (data[0] == 0x78 && data[1] == 0x9C) return true; // zlib
      if (data[0] == 0x04 && data[1] == 0x22) return true; // LZ4
    }
    
    // Check for low entropy (already compressed)
    final byteCounts = List<int>.filled(256, 0);
    for (int i = 0; i < data.length; i++) {
      byteCounts[data[i]]++;
    }
    
    // Calculate entropy
    double entropy = 0;
    for (int count in byteCounts) {
      if (count > 0) {
        double p = count / data.length;
        entropy -= p * (p > 0 ? log(p) : 0);
      }
    }
    
    // Low entropy suggests already compressed
    return entropy < 4.0;
  }
  
  /// Simple LZ4-like compression implementation
  static Uint8List _lz4Compress(Uint8List data) {
    final List<int> output = [];
    int pos = 0;
    
    while (pos < data.length) {
      // Find longest match
      int matchLen = 0;
      int matchOffset = 0;
      
      // Look for matches in previous 64KB
      final searchStart = pos > 65536 ? pos - 65536 : 0;
      for (int i = searchStart; i < pos; i++) {
        int len = 0;
        while (pos + len < data.length && 
               i + len < pos && 
               data[pos + len] == data[i + len] && 
               len < 255) {
          len++;
        }
        
        if (len > matchLen && len >= 4) {
          matchLen = len;
          matchOffset = pos - i;
        }
      }
      
      if (matchLen >= 4) {
        // Write match
        output.add(0); // Literal length = 0
        output.add(matchLen);
        output.add(matchOffset & 0xFF);
        output.add((matchOffset >> 8) & 0xFF);
        pos += matchLen;
      } else {
        // Write literal
        int literalLen = 0;
        while (pos + literalLen < data.length && literalLen < 255) {
          // Check if next byte would start a match
          bool hasMatch = false;
          if (pos + literalLen + 3 < data.length) {
            for (int i = searchStart; i < pos + literalLen; i++) {
              if (i + 3 < pos + literalLen &&
                  data[pos + literalLen] == data[i] &&
                  data[pos + literalLen + 1] == data[i + 1] &&
                  data[pos + literalLen + 2] == data[i + 2] &&
                  data[pos + literalLen + 3] == data[i + 3]) {
                hasMatch = true;
                break;
              }
            }
          }
          
          if (hasMatch) break;
          literalLen++;
        }
        
        output.add(literalLen);
        for (int i = 0; i < literalLen; i++) {
          output.add(data[pos + i]);
        }
        pos += literalLen;
      }
    }
    
    return Uint8List.fromList(output);
  }
  
  /// Simple LZ4-like decompression implementation
  static Uint8List _lz4Decompress(Uint8List compressedData, int originalSize) {
    final List<int> output = [];
    int pos = 0;
    
    while (pos < compressedData.length && output.length < originalSize) {
      if (pos >= compressedData.length) break;
      
      final literalLen = compressedData[pos++];
      
      // Copy literal data
      if (literalLen > 0) {
        for (int i = 0; i < literalLen && pos < compressedData.length; i++) {
          output.add(compressedData[pos++]);
        }
      }
      
      // Check if we have enough data for a match
      if (pos + 2 < compressedData.length) {
        final matchLen = compressedData[pos++];
        if (pos + 1 < compressedData.length) {
          final matchOffset = compressedData[pos] | (compressedData[pos + 1] << 8);
          pos += 2;
          
          // Copy match data
          if (matchLen > 0 && matchOffset > 0) {
            final matchStart = output.length - matchOffset;
            for (int i = 0; i < matchLen && output.length < originalSize; i++) {
              if (matchStart + i >= 0 && matchStart + i < output.length) {
                output.add(output[matchStart + i]);
              }
            }
          }
        }
      }
    }
    
    return Uint8List.fromList(output);
  }
} 