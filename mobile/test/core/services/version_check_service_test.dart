import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/services/version_check_service.dart';

void main() {
  group('VersionCheckService Store Compliance Suite', () {
    test('should trigger forced update when local build is below remote minimum', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/config/app-version'));
        return http.Response(
          jsonEncode({
            'min_ios_build': 5,
            'min_ios_version': '1.2.0',
            'min_android_build': 5,
            'min_android_version': '1.2.0',
            'ios_store_url': 'https://apps.apple.com/app/reparatutti/id1234567890',
            'android_store_url': 'https://play.google.com/store/apps/details?id=com.reparatutti.app',
            'force_update_message': 'Actualización obligatoria para continuar operando.',
          }),
          200,
        );
      });

      final service = VersionCheckService(
        baseUrl: 'http://api.reparatutti.com/api/v1',
        client: mockClient,
      );

      // Current build 1 vs remote min build 5
      final result = await service.checkForUpdates(currentBuild: 1);

      expect(result.needsForceUpdate, isTrue);
      expect(result.currentBuild, equals(1));
      expect(result.minRequiredBuild, equals(5));
      expect(result.storeUrl, isNotEmpty);
      expect(result.message, equals('Actualización obligatoria para continuar operando.'));
    });

    test('should allow launch without forced update when local build is up to date', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'min_ios_build': 1,
            'min_ios_version': '1.0.0',
            'min_android_build': 1,
            'min_android_version': '1.0.0',
            'ios_store_url': 'https://apps.apple.com',
            'android_store_url': 'https://play.google.com',
            'force_update_message': '',
          }),
          200,
        );
      });

      final service = VersionCheckService(
        baseUrl: 'http://api.reparatutti.com/api/v1',
        client: mockClient,
      );

      final result = await service.checkForUpdates(currentBuild: 1);

      expect(result.needsForceUpdate, isFalse);
    });

    test('should fail gracefully if remote server is unreachable', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection reset by peer');
      });

      final service = VersionCheckService(
        baseUrl: 'http://unreachable.reparatutti.com/api/v1',
        client: mockClient,
      );

      // Startup should not crash the app if offline
      final result = await service.checkForUpdates(currentBuild: 1);
      expect(result.needsForceUpdate, isFalse);
    });
  });
}
