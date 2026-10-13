import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class AppUpdateCheckResult {
  final bool needsForceUpdate;
  final int currentBuild;
  final int minRequiredBuild;
  final String storeUrl;
  final String message;

  const AppUpdateCheckResult({
    required this.needsForceUpdate,
    required this.currentBuild,
    required this.minRequiredBuild,
    required this.storeUrl,
    required this.message,
  });

  factory AppUpdateCheckResult.upToDate(int currentBuild) {
    return AppUpdateCheckResult(
      needsForceUpdate: false,
      currentBuild: currentBuild,
      minRequiredBuild: currentBuild,
      storeUrl: '',
      message: '',
    );
  }
}

class VersionCheckService {
  final String baseUrl;
  final http.Client _client;

  // Build number matching pubspec.yaml: 1.0.0+1
  static const int currentAppBuildNumber = 1;
  static const String currentAppVersion = '1.0.0';

  VersionCheckService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
        _client = client ?? http.Client();

  static String _resolveDefaultBaseUrl() {
    // Emulator loopbacks
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  /// Evaluates remote configuration against current local app build number
  Future<AppUpdateCheckResult> checkForUpdates({
    int currentBuild = currentAppBuildNumber,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/config/app-version');
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode != 200) {
        debugPrint('[VersionCheck] Remote config returned HTTP ${response.statusCode}, allowing launch.');
        return AppUpdateCheckResult.upToDate(currentBuild);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      final int minRequiredBuild = isIOS
          ? (data['min_ios_build'] as num? ?? 1).toInt()
          : (data['min_android_build'] as num? ?? 1).toInt();

      final String storeUrl = isIOS
          ? (data['ios_store_url'] as String? ?? 'https://apps.apple.com')
          : (data['android_store_url'] as String? ?? 'https://play.google.com');

      final String message = data['force_update_message'] as String? ??
          'Una actualización de seguridad crítica es requerida para continuar utilizando Reparatutti.';

      final bool needsForceUpdate = currentBuild < minRequiredBuild;

      debugPrint('[VersionCheck] Current Build: $currentBuild | Min Required: $minRequiredBuild | Forced: $needsForceUpdate');

      return AppUpdateCheckResult(
        needsForceUpdate: needsForceUpdate,
        currentBuild: currentBuild,
        minRequiredBuild: minRequiredBuild,
        storeUrl: storeUrl,
        message: message,
      );
    } catch (e) {
      // Graceful fallback: Network failure at startup should not block the user unless offline strict
      debugPrint('[VersionCheck] Remote config unreachable ($e), falling back to allowed launch.');
      return AppUpdateCheckResult.upToDate(currentBuild);
    }
  }
}

// -----------------------------------------------------------------------------
// RIVERPOD PROVIDERS
// -----------------------------------------------------------------------------

final versionCheckServiceProvider = Provider<VersionCheckService>((ref) {
  return VersionCheckService();
});

final appUpdateStateProvider = FutureProvider<AppUpdateCheckResult>((ref) async {
  final service = ref.watch(versionCheckServiceProvider);
  return await service.checkForUpdates();
});
