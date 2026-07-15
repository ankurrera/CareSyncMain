import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:caresync/services/encryption_service.dart';

void main() {
  group('EncryptionService AES and Hybrid Fallback Tests', () {
    const String testPatientId = 'd3b07384-d113-4ec6-a5d6-c0cf4d5a6843';
    const String testVitalsValue = '120/80';
    const String testClinicalNote =
        'Patient exhibits normal blood pressure readings.';

    // Helper for legacy XOR encryption
    Uint8List xorEncrypt(Uint8List data, Uint8List key) {
      final result = Uint8List(data.length);
      for (int i = 0; i < data.length; i++) {
        result[i] = data[i] ^ key[i % key.length];
      }
      return result;
    }

    String generateLegacyXorCiphertext(String plaintext, String patientId) {
      final key = Uint8List.fromList(
        sha256.convert(utf8.encode(patientId)).bytes,
      );
      final plaintextBytes = utf8.encode(plaintext);
      final encryptedBytes = xorEncrypt(plaintextBytes, key);
      return base64Encode(encryptedBytes);
    }

    test('AES-256 Symmetric Encryption & Decryption (CBC)', () async {
      final key = Uint8List.fromList(
        sha256.convert(utf8.encode(testPatientId)).bytes,
      );

      // Encrypt using new AES-256 implementation
      final encrypted = await EncryptionService.instance.encryptData(
        testClinicalNote,
        key,
      );
      expect(
        encrypted,
        contains(':'),
      ); // New format: iv_base64:ciphertext_base64

      // Decrypt using AES-256 implementation
      final decrypted = await EncryptionService.instance.decryptData(
        encrypted,
        key,
      );
      expect(decrypted, equals(testClinicalNote));
    });

    test(
      'Deterministic Encryption & Decryption for Vitals (AES Format)',
      () async {
        // Encrypt using deterministic patientId key
        final encrypted = await EncryptionService.instance.encryptMedicalRecord(
          data: testVitalsValue,
          patientId: testPatientId,
        );
        expect(encrypted, contains(':'));

        // Decrypt using deterministic patientId key
        final decrypted = EncryptionService.instance.decryptDeterministic(
          encryptedData: encrypted,
          patientId: testPatientId,
        );
        expect(decrypted, equals(testVitalsValue));
      },
    );

    test('Hybrid Fallback: Decryption of Legacy XOR Encrypted Data', () {
      // Generate legacy XOR ciphertext
      final legacyCiphertext = generateLegacyXorCiphertext(
        testVitalsValue,
        testPatientId,
      );
      expect(
        legacyCiphertext,
        isNot(contains(':')),
      ); // Legacy format lacks colon

      // Decrypt legacy XOR ciphertext using new deterministic hybrid fallback
      final decrypted = EncryptionService.instance.decryptDeterministic(
        encryptedData: legacyCiphertext,
        patientId: testPatientId,
      );
      expect(decrypted, equals(testVitalsValue));
    });

    test('Integrity Hashing Output Consistency', () {
      final hash1 = EncryptionService.instance.hashData(testClinicalNote);
      final hash2 = EncryptionService.instance.hashData(testClinicalNote);
      expect(hash1, equals(hash2));
    });
  });
}
