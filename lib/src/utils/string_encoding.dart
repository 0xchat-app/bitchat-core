/// String encoding utilities for bitchat
/// Handles UTF-8 encoding/decoding for proper Chinese character support
import 'dart:convert';
import 'dart:typed_data';

/// String encoding utilities for bitchat
class StringEncoding {
  /// Convert string to UTF-8 bytes
  static Uint8List stringToBytes(String str) {
    return Uint8List.fromList(utf8.encode(str));
  }
  
  /// Convert UTF-8 bytes to string
  static String bytesToString(Uint8List bytes) {
    return utf8.decode(bytes);
  }
  
  /// Convert string to code units (for backward compatibility)
  static Uint8List stringToCodeUnits(String str) {
    return Uint8List.fromList(str.codeUnits);
  }
  
  /// Convert code units to string (for backward compatibility)
  static String codeUnitsToString(Uint8List bytes) {
    return String.fromCharCodes(bytes);
  }
  
  /// Safe string to bytes conversion (prefer UTF-8)
  static Uint8List safeStringToBytes(String str) {
    try {
      // Try UTF-8 first
      return stringToBytes(str);
    } catch (e) {
      // Fallback to code units
      return stringToCodeUnits(str);
    }
  }
  
  /// Safe bytes to string conversion (prefer UTF-8)
  static String safeBytesToString(Uint8List bytes) {
    try {
      // Try UTF-8 first
      return bytesToString(bytes);
    } catch (e) {
      // Fallback to code units
      return codeUnitsToString(bytes);
    }
  }
} 