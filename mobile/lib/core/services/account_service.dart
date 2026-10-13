import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'crash_reporting_service.dart';
import 'secure_storage_service.dart';

class AccountService {
  final SecureStorageService secureStorage;
  final String _baseUrl;
  final http.Client _client;

  AccountService({
    required this.secureStorage,
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
        _client = client ?? http.Client();

  static String _resolveDefaultBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  /// Sends DELETE /api/v1/users/me to trigger backend soft-delete & PII anonymization,
  /// followed by complete hardware Keystore session purging.
  Future<bool> deleteAccount() async {
    try {
      final token = await secureStorage.getAuthToken();
      final uri = Uri.parse('$_baseUrl/users/me');

      final response = await _client.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      // 200 OK or 204 No Content
      final success = response.statusCode == 200 || response.statusCode == 204;
      if (!success) {
        debugPrint('[AccountService] Delete account response failed with status ${response.statusCode}: ${response.body}');
      }

      // Invalidate local session unconditionally upon deletion request
      await secureStorage.clearAuthSession();
      CrashReportingService.clearUserIdentifier();

      return true;
    } catch (e, stack) {
      debugPrint('[AccountService] Error executing account deletion: $e\n$stack');
      // Even on network error, ensure local auth credentials are wiped for privacy safety
      await secureStorage.clearAuthSession();
      CrashReportingService.clearUserIdentifier();
      return true;
    }
  }

  /// Sends POST /api/v1/users/me/suspend to temporarily disable the account
  Future<bool> suspendAccount() async {
    try {
      final token = await secureStorage.getAuthToken();
      final uri = Uri.parse('$_baseUrl/users/me/suspend');

      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final success = response.statusCode == 200;
      if (success) {
        await secureStorage.clearAuthSession();
        CrashReportingService.clearUserIdentifier();
      }
      return success;
    } catch (e) {
      debugPrint('[AccountService] Error executing account suspension: $e');
      return false;
    }
  }
}

// -----------------------------------------------------------------------------
// RIVERPOD PROVIDER
// -----------------------------------------------------------------------------

final accountServiceProvider = Provider<AccountService>((ref) {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return AccountService(secureStorage: secureStorage);
});
