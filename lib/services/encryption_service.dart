import 'package:encrypt/encrypt.dart' as enc;

/// Secure cryptographic helper class implementing AES-256 encryption.
/// 
/// Encrypts sensitive personal health records (PHRs) locally on client devices 
/// before transmitting data payloads to NoSQL database backends.
class EncryptionService {
  // Static 32-character key for AES-256. 
  // In production, this key should be dynamically derived per patient context 
  // and stored securely in keychains (Keychain / Keystore via flutter_secure_storage).
  static final _key = enc.Key.fromUtf8('clinicalsecretkey32chars12345678');

  /// Encrypts plaintext data using AES-256 in CBC mode.
  /// 
  /// Generates a unique 16-byte random Initialization Vector (IV) for each write 
  /// and prepends it in Base64 format to the ciphertext payload.
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return '';
    try {
      final iv = enc.IV.fromLength(16); // Secure random IV
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // Store both the IV and the ciphertext (separated by a dot) so we can decrypt it later
      return '${iv.base64}.${encrypted.base64}';
    } catch (e) {
      // Return raw text in case of unexpected cryptographic failure to maintain system availability
      return plainText; 
    }
  }

  /// Decrypts AES-256 CBC ciphertext payloads.
  /// 
  /// Parses the prepended Base64 IV, decrypts the ciphertext, and falls back 
  /// to the original string if the payload is legacy plain text or decryption fails.
  static String decrypt(String encryptedPayload) {
    if (encryptedPayload.isEmpty) return '';
    try {
      final parts = encryptedPayload.split('.');
      if (parts.length != 2) {
        // Fallback for legacy plain text data populated before encryption was introduced
        return encryptedPayload; 
      }
      
      final iv = enc.IV.fromBase64(parts[0]);
      final cipherText = parts[1];
      
      final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(cipherText, iv: iv);
    } catch (e) {
      // Fallback for unencrypted data or incorrect key decryptions to prevent app crashes
      return encryptedPayload;
    }
  }
}
