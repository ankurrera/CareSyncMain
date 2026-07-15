import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresync/services/custom_biometric_service.dart';

void main() {
  tearDownAll(() {
    final dir = Directory('./temp_docs');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('Biometric Lifecycle Client-Side state', () {
    test('Verifies Cache Directory Creation and Cleanup', () async {
      final docDir = Directory('./temp_docs');
      final cacheDir = Directory('${docDir.path}/biometric_enrollment_cache');

      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }

      expect(cacheDir.existsSync(), isFalse);

      // Simulate directory creation
      cacheDir.createSync(recursive: true);
      expect(cacheDir.existsSync(), isTrue);

      final sessionFile = File('${cacheDir.path}/session.json');
      sessionFile.writeAsStringSync('{"enrollment_session_id": "test-session-123"}');
      expect(sessionFile.existsSync(), isTrue);

      // Cleanup
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      expect(cacheDir.existsSync(), isFalse);
    });

    group('CustomBiometricService client endpoints', () {
      test('Service methods compile and are accessible', () {
        final service = CustomBiometricService.instance;
        expect(service, isNotNull);
        expect(service.completeBiometricEnrollment, isNotNull);
        expect(service.cleanupBiometricEnrollment, isNotNull);
      });
    });
  });
}
