import 'dart:convert';
import 'package:crypto/crypto.dart';

class ConflictResolver {
  ConflictResolver._privateConstructor();
  static final ConflictResolver instance =
      ConflictResolver._privateConstructor();

  // Computes a deterministic hash for duplicate detection
  String generateDuplicateHash({
    required String patientId,
    required String type,
    required String value,
    required String recordedAt,
  }) {
    final rawBytes = utf8.encode('$patientId:$type:$value:$recordedAt');
    return sha256.convert(rawBytes).toString();
  }

  // Returns true if the incoming vital points overlap with existing records
  // and need override or separate insertion
  bool shouldOverride(String sourceA, String sourceB) {
    // Override policy: manual edits always prioritize over wearable sync
    if (sourceA == 'manual' && sourceB != 'manual') {
      return true;
    }
    return false;
  }
}
