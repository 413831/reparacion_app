import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/services/account_service.dart';
import 'package:mobile/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountService Store Compliance & Privacy Tests', () {
    late SecureStorageService storage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({
        'reparatutti_auth_token': 'jwt_active_token_123',
        'reparatutti_user_id': 'user_id_456',
      });
      storage = SecureStorageService();
    });

    test('deleteAccount calls DELETE /api/v1/users/me and wipes hardware session storage', () async {
      bool deleteEndpointCalled = false;

      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' && request.url.path.endsWith('/users/me')) {
          deleteEndpointCalled = true;
          expect(request.headers['Authorization'], equals('Bearer jwt_active_token_123'));
          return http.Response(
            jsonEncode({'status': 'deleted', 'message': 'Account deleted'}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final accountService = AccountService(
        secureStorage: storage,
        baseUrl: 'http://test.api.reparatutti.com/api/v1',
        client: mockClient,
      );

      // Verify token exists before deletion
      expect(await storage.getAuthToken(), equals('jwt_active_token_123'));

      // Perform deletion
      final result = await accountService.deleteAccount();

      expect(result, isTrue);
      expect(deleteEndpointCalled, isTrue);

      // Verify session has been completely purged from hardware storage
      expect(await storage.getAuthToken(), isNull);
      expect(await storage.getUserId(), isNull);
    });

    test('suspendAccount calls POST /api/v1/users/me/suspend and invalidates session', () async {
      bool suspendEndpointCalled = false;

      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/users/me/suspend')) {
          suspendEndpointCalled = true;
          return http.Response(
            jsonEncode({'status': 'suspended'}),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final accountService = AccountService(
        secureStorage: storage,
        baseUrl: 'http://test.api.reparatutti.com/api/v1',
        client: mockClient,
      );

      final result = await accountService.suspendAccount();

      expect(result, isTrue);
      expect(suspendEndpointCalled, isTrue);
      expect(await storage.getAuthToken(), isNull);
    });
  });
}
