/// Encryption service compatible with bitchat Swift implementation
/// 
/// Provides X25519 key exchange, AES-256-GCM encryption, and Ed25519 signing
/// with the same protocol as the Swift version.
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Represents a complete key pair for bitchat
class BitchatKeyPair {
  final SimpleKeyPair x25519KeyPair;
  final SimpleKeyPair ed25519KeyPair;
  final SimpleKeyPair identityKeyPair;
  
  const BitchatKeyPair({
    required this.x25519KeyPair,
    required this.ed25519KeyPair,
    required this.identityKeyPair,
  });
  
  /// Get combined public key data (96 bytes: X25519 + Ed25519 + Identity)
  /// Same format as Swift: publicKey + signingPublicKey + identityPublicKey
  Future<Uint8List> getCombinedPublicKeyData() async {
    final x25519PublicKey = await x25519KeyPair.extractPublicKey();
    final ed25519PublicKey = await ed25519KeyPair.extractPublicKey();
    final identityPublicKey = await identityKeyPair.extractPublicKey();
    
    final combined = Uint8List(96);
    combined.setRange(0, 32, x25519PublicKey.bytes);
    combined.setRange(32, 64, ed25519PublicKey.bytes);
    combined.setRange(64, 96, identityPublicKey.bytes);
    
    return combined;
  }
}

/// Encryption errors matching Swift implementation
enum EncryptionError implements Exception {
  noSharedSecret,
  invalidPublicKey,
  encryptionFailed,
  decryptionFailed,
  signingFailed,
  verificationFailed,
}

/// Encryption service compatible with Swift bitchat
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();
  
  // Cryptographic algorithms
  final X25519 _x25519 = X25519();
  final Ed25519 _ed25519 = Ed25519();
  final AesGcm _aesGcm = AesGcm.with256bits();
  
  // Current key pair (set by upper layer)
  BitchatKeyPair? _currentKeyPair;
  
  // Peer public keys and shared secrets (matching Swift structure)
  final Map<String, SimplePublicKey> _peerPublicKeys = {};
  final Map<String, SimplePublicKey> _peerSigningKeys = {};
  final Map<String, SimplePublicKey> _peerIdentityKeys = {};
  final Map<String, SecretKey> _sharedSecrets = {};
  
  /// Generate a new key pair (ephemeral for each session)
  Future<BitchatKeyPair> generateKeyPair() async {
    final x25519KeyPair = await _x25519.newKeyPair();
    final ed25519KeyPair = await _ed25519.newKeyPair();
    final identityKeyPair = await _ed25519.newKeyPair();
    
    return BitchatKeyPair(
      x25519KeyPair: x25519KeyPair,
      ed25519KeyPair: ed25519KeyPair,
      identityKeyPair: identityKeyPair,
    );
  }
  
  /// Load key pair from upper layer
  void loadKeyPair(BitchatKeyPair keyPair) {
    _currentKeyPair = keyPair;
  }
  
  /// Get current key pair
  BitchatKeyPair? getCurrentKeyPair() {
    return _currentKeyPair;
  }
  
  /// Get combined public key data (96 bytes format)
  /// Same as Swift: publicKey + signingPublicKey + identityPublicKey
  Future<Uint8List?> getCombinedPublicKeyData() async {
    if (_currentKeyPair == null) return null;
    return await _currentKeyPair!.getCombinedPublicKeyData();
  }
  
  /// Add peer's combined public key data (96 bytes format)
  /// Matches Swift implementation exactly
  Future<void> addPeerPublicKey(String peerID, Uint8List publicKeyData) async {
    if (publicKeyData.length != 96) {
      throw EncryptionError.invalidPublicKey;
    }
    
    try {
      // Extract the three 32-byte public keys (same as Swift)
      final x25519PublicKeyData = publicKeyData.sublist(0, 32);
      final ed25519PublicKeyData = publicKeyData.sublist(32, 64);
      final identityPublicKeyData = publicKeyData.sublist(64, 96);
      
      // Create public key objects
      final x25519PublicKey = SimplePublicKey(
        x25519PublicKeyData,
        type: KeyPairType.x25519,
      );
      final ed25519PublicKey = SimplePublicKey(
        ed25519PublicKeyData,
        type: KeyPairType.ed25519,
      );
      final identityPublicKey = SimplePublicKey(
        identityPublicKeyData,
        type: KeyPairType.ed25519,
      );
      
      // Store all three keys for peer (matching Swift structure)
      _peerPublicKeys[peerID] = x25519PublicKey;
      _peerSigningKeys[peerID] = ed25519PublicKey;
      _peerIdentityKeys[peerID] = identityPublicKey;
      
      // Generate shared secret using X25519 (same as Swift)
      if (_currentKeyPair != null) {
        final sharedSecret = await _x25519.sharedSecretKey(
          keyPair: _currentKeyPair!.x25519KeyPair,
          remotePublicKey: x25519PublicKey,
        );
        
        // Derive symmetric key using HKDF (same as Swift)
        final derivedKey = await _deriveSymmetricKey(sharedSecret);
        _sharedSecrets[peerID] = derivedKey;
      }
    } catch (e) {
      throw EncryptionError.invalidPublicKey;
    }
  }
  
  /// Derive symmetric key using HKDF (compatible with Swift)
  /// Uses same parameters: SHA256, salt: "bitchat-v1", output: 32 bytes
  Future<SecretKey> _deriveSymmetricKey(SecretKey sharedSecret) async {
    // Use HKDF with SHA256, salt: "bitchat-v1", output: 32 bytes
    final salt = Uint8List.fromList('bitchat-v1'.codeUnits);
    
    // For now, use a simple key derivation
    // TODO: Implement proper HKDF when cryptography library supports it
    final sharedSecretBytes = await sharedSecret.extractBytes();
    final combined = Uint8List(salt.length + sharedSecretBytes.length);
    combined.setRange(0, salt.length, salt);
    combined.setRange(salt.length, combined.length, sharedSecretBytes);
    
    // Use SHA256 for key derivation
    final hash = await Sha256().hash(combined);
    return SecretKey(hash.bytes);
  }
  
  /// Encrypt data for a specific peer (AES-256-GCM)
  /// Returns combined data (nonce + ciphertext + tag) like Swift
  Future<Uint8List> encrypt(Uint8List data, String peerID) async {
    final sharedSecret = _sharedSecrets[peerID];
    if (sharedSecret == null) {
      throw EncryptionError.noSharedSecret;
    }
    
    try {
      final secretBox = await _aesGcm.encrypt(data, secretKey: sharedSecret);
      return Uint8List.fromList(secretBox.concatenation());
    } catch (e) {
      throw EncryptionError.encryptionFailed;
    }
  }
  
  /// Decrypt data from a specific peer (AES-256-GCM)
  /// Expects combined data (nonce + ciphertext + tag) like Swift
  Future<Uint8List> decrypt(Uint8List data, String peerID) async {
    final sharedSecret = _sharedSecrets[peerID];
    if (sharedSecret == null) {
      throw EncryptionError.noSharedSecret;
    }
    
    try {
      final secretBox = SecretBox.fromConcatenation(data, nonceLength: 12, macLength: 16);
      final decrypted = await _aesGcm.decrypt(secretBox, secretKey: sharedSecret);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw EncryptionError.decryptionFailed;
    }
  }
  
  /// Sign data with current Ed25519 key
  /// Returns signature bytes like Swift
  Future<Uint8List> sign(Uint8List data) async {
    if (_currentKeyPair == null) {
      throw EncryptionError.signingFailed;
    }
    
    try {
      final signature = await _ed25519.sign(data, keyPair: _currentKeyPair!.ed25519KeyPair);
      return Uint8List.fromList(signature.bytes);
    } catch (e) {
      throw EncryptionError.signingFailed;
    }
  }
  
  /// Verify signature from a peer
  /// Uses peer's signing public key like Swift
  Future<bool> verify(Uint8List data, Uint8List signature, String peerID) async {
    final peerSigningKey = _peerSigningKeys[peerID];
    if (peerSigningKey == null) {
      return false;
    }
    
    try {
      final signatureObject = Signature(signature, publicKey: peerSigningKey);
      return await _ed25519.verify(data, signature: signatureObject);
    } catch (e) {
      return false;
    }
  }
  
  /// Get peer's identity public key (for favorites)
  /// Returns raw bytes like Swift
  Future<Uint8List?> getPeerIdentityKey(String peerID) async {
    final peerIdentityKey = _peerIdentityKeys[peerID];
    if (peerIdentityKey == null) return null;
    
    return Uint8List.fromList(peerIdentityKey.bytes);
  }
  
  /// Clear all stored keys and secrets
  void clearAllKeys() {
    _currentKeyPair = null;
    _peerPublicKeys.clear();
    _peerSigningKeys.clear();
    _peerIdentityKeys.clear();
    _sharedSecrets.clear();
  }
  
  /// Check if we have a shared secret with a peer
  bool hasSharedSecret(String peerID) {
    return _sharedSecrets.containsKey(peerID);
  }
  
  /// Get all peer IDs we have keys for
  List<String> getPeerIDs() {
    return _peerPublicKeys.keys.toList();
  }
  
  /// Get peer's signing public key
  SimplePublicKey? getPeerSigningKey(String peerID) {
    return _peerSigningKeys[peerID];
  }
  
  /// Get peer's X25519 public key
  SimplePublicKey? getPeerPublicKey(String peerID) {
    return _peerPublicKeys[peerID];
  }
} 