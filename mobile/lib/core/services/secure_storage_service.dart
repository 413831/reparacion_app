import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SecureStorageService provides hardware-backed encrypted storage
/// for sensitive authentication tokens and personal data (PII).
/// 
/// Uses Android Keystore (via EncryptedSharedPreferences) and 
/// iOS Keychain (with KeychainAccessibility.first_unlock) to guarantee
/// encryption-at-rest across mobile platforms.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  // Well-defined keys for session and PII
  static const String _keyAuthToken = 'reparatutti_auth_token';
  static const String _keyRefreshToken = 'reparatutti_refresh_token';
  static const String _keyUserId = 'reparatutti_user_id';
  static const String _keyUserRole = 'reparatutti_user_role';
  static const String _keyUserData = 'reparatutti_user_data';

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  // ---------------------------------------------------------------------------
  // AUTH TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Persists the JWT authentication token securely in hardware keystore.
  Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _keyAuthToken, value: token);
    } catch (e) {
      debugPrint('[SecureStorage] Error saving auth token: $e');
      rethrow;
    }
  }

  /// Retrieves the decrypted JWT authentication token.
  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _keyAuthToken);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading auth token: $e');
      return null;
    }
  }

  /// Removes the stored auth token upon logout or session invalidation.
  Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: _keyAuthToken);
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting auth token: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // REFRESH TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Persists the OAuth/JWT refresh token.
  Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      debugPrint('[SecureStorage] Error saving refresh token: $e');
      rethrow;
    }
  }

  /// Retrieves the stored refresh token.
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading refresh token: $e');
      return null;
    }
  }

  /// Removes the stored refresh token.
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('[SecureStorage] Error deleting refresh token: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // USER METADATA & PII MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Saves the authenticated user's ID.
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  /// Retrieves the authenticated user's ID.
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  /// Saves user role ('client', 'technician', 'admin').
  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _keyUserRole, value: role);
  }

  /// Retrieves stored user role.
  Future<String?> getUserRole() async {
    return await _storage.read(key: _keyUserRole);
  }

  /// Securely stores user profile metadata / PII encoded in JSON.
  Future<void> saveUserData(Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      await _storage.write(key: _keyUserData, value: jsonString);
    } catch (e) {
      debugPrint('[SecureStorage] Error saving user data: $e');
      rethrow;
    }
  }

  /// Retrieves and decodes stored user metadata / PII.
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final jsonString = await _storage.read(key: _keyUserData);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[SecureStorage] Error reading user data: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // SESSION LIFECYCLE
  // ---------------------------------------------------------------------------

  /// Checks if an active authenticated session token exists.
  Future<bool> hasValidSession() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Clears all user session credentials and sensitive tokens upon logout.
  Future<void> clearAuthSession() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyAuthToken),
        _storage.delete(key: _keyRefreshToken),
        _storage.delete(key: _keyUserId),
        _storage.delete(key: _keyUserRole),
        _storage.delete(key: _keyUserData),
      ]);
    } catch (e) {
      debugPrint('[SecureStorage] Error clearing auth session: $e');
      rethrow;
    }
  }

  /// Completely purges all items stored in hardware-backed secure storage.
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('[SecureStorage] Error wiping secure storage: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GENERIC RAW ENCRYPTED ACCESSORS
  // ---------------------------------------------------------------------------

  /// Encrypt and store arbitrary key-value pairs.
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read and decrypt value by key.
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Check whether key exists in storage.
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// Delete specific key from secure storage.
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

// -----------------------------------------------------------------------------
// RIVERPOD DEPENDENCY INJECTION PROVIDERS
// -----------------------------------------------------------------------------

/// Global provider for the SecureStorageService instance.
final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Reactive FutureProvider providing current JWT token.
final authTokenProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  return await storage.getAuthToken();
});

/// Reactive FutureProvider indicating if an active user session exists.
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  return await storage.hasValidSession();
});
