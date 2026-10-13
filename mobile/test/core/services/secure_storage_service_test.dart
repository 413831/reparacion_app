import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/core/services/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService DevSecOps Test Suite', () {
    late SecureStorageService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      service = SecureStorageService();
    });

    test('should save, read, and delete JWT auth token', () async {
      const mockToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.fake_signature';

      // 1. Initial state: no token
      expect(await service.getAuthToken(), isNull);
      expect(await service.hasValidSession(), isFalse);

      // 2. Save token
      await service.saveAuthToken(mockToken);
      expect(await service.getAuthToken(), equals(mockToken));
      expect(await service.hasValidSession(), isTrue);

      // 3. Delete token
      await service.deleteAuthToken();
      expect(await service.getAuthToken(), isNull);
      expect(await service.hasValidSession(), isFalse);
    });

    test('should save, read, and delete OAuth refresh token', () async {
      const mockRefreshToken = 'refresh_token_xyz_123456';

      expect(await service.getRefreshToken(), isNull);

      await service.saveRefreshToken(mockRefreshToken);
      expect(await service.getRefreshToken(), equals(mockRefreshToken));

      await service.deleteRefreshToken();
      expect(await service.getRefreshToken(), isNull);
    });

    test('should encrypt and serialize user PII metadata to JSON', () async {
      final mockUserData = {
        'id': '8ef9302e-1310-449e-ba7f-712808c1a850',
        'email': 'tecnico.plomero@reparatutti.com.ar',
        'full_name': 'Mario Gonzalez',
        'role': 'technician',
        'trade': 'plomeria',
        'kyc_status': 'verified',
      };

      // 1. Save data
      await service.saveUserData(mockUserData);

      // 2. Read and verify decoded map
      final retrievedData = await service.getUserData();
      expect(retrievedData, isNotNull);
      expect(retrievedData!['id'], equals(mockUserData['id']));
      expect(retrievedData['email'], equals(mockUserData['email']));
      expect(retrievedData['role'], equals('technician'));
      expect(retrievedData['kyc_status'], equals('verified'));
    });

    test('should clear all session tokens upon clearAuthSession()', () async {
      await service.saveAuthToken('jwt.active.token');
      await service.saveRefreshToken('refresh.active.token');
      await service.saveUserId('user-uuid-123');
      await service.saveUserRole('client');
      await service.saveUserData({'name': 'Juan Cliente'});

      expect(await service.hasValidSession(), isTrue);

      // Invoke session termination
      await service.clearAuthSession();

      expect(await service.getAuthToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
      expect(await service.getUserId(), isNull);
      expect(await service.getUserRole(), isNull);
      expect(await service.getUserData(), isNull);
      expect(await service.hasValidSession(), isFalse);
    });

    test('should support generic raw encrypted key-value operations', () async {
      const customKey = 'security_fingerprint';
      const customVal = 'sha256-abcdef123456';

      expect(await service.containsKey(customKey), isFalse);

      await service.write(customKey, customVal);
      expect(await service.containsKey(customKey), isTrue);
      expect(await service.read(customKey), equals(customVal));

      await service.delete(customKey);
      expect(await service.containsKey(customKey), isFalse);
      expect(await service.read(customKey), isNull);
    });
  });
}
