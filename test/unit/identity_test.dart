import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_mark/utils/identity_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IdentityManager Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Should generate a new key if none exists', () async {
      final publicKey = await IdentityManager.getDevicePublicKey();
      expect(publicKey, isNotEmpty);
      expect(publicKey.length, greaterThan(20));

      final fingerprint = await IdentityManager.getDeviceFingerprint();
      expect(fingerprint, contains('...'));
    });

    test('Should persist and retrieve the same key', () async {
      await IdentityManager.resetIdentity();
      FlutterSecureStorage.setMockInitialValues({});
      final firstKey = await IdentityManager.getDevicePublicKey();

      const storage = FlutterSecureStorage();
      final storedKey = await storage.read(key: 'device_public_key');
      expect(storedKey, equals(firstKey));
    });
  });
}
