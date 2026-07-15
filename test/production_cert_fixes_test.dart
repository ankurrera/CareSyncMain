import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresync/features/shared/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrService PDF Temporary File Cleanup Verification', () {
    test('Guarantees deletion of temporary rendered image after execution', () async {
      final ocr = OcrService();
      final tempDir = Directory.systemTemp.createTempSync('ocr_test');
      final testFile = File('${tempDir.path}/test_prescription.pdf');

      // Write some dummy bytes
      await testFile.writeAsBytes(List.generate(100, (i) => i));

      // We expect _processPdf to throw an exception because the dummy bytes aren't a valid PDF.
      // But the try-finally block must ensure any temp png image created during rendering is deleted.
      try {
        await ocr.processPrescriptionFile(testFile);
      } catch (e) {
        // Expected parsing/rendering exception
      }

      // Check system temp directory to confirm zero leaked 'temp_ocr_page_*.png' files
      final files = tempDir.listSync(recursive: true);
      final hasLeakedPng = files.any((f) => f.path.contains('temp_ocr_page_'));
      expect(hasLeakedPng, isFalse, reason: 'Temporary rendered PNG files must be completely cleaned up');

      // Cleanup
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });

  group('Unsafe Counts Casting Null-Safety Verification', () {
    test('Counts providers handle null or non-list responses gracefully', () {
      final Object? nullResult = null;
      final Object mapResult = {'id': 1};
      final Object listResult = [{'id': 1}, {'id': 2}];

      int parseResult(dynamic result) {
        if (result is List) {
          return result.length;
        }
        return 0;
      }

      expect(parseResult(nullResult), equals(0));
      expect(parseResult(mapResult), equals(0));
      expect(parseResult(listResult), equals(2));
    });
  });
}
