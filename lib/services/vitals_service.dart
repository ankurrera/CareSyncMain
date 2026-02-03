import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/patient/models/vital.dart';
import 'supabase_service.dart';
import 'encryption_service.dart';

class VitalsService {
  VitalsService(this._supabase, this._encryption);

  final SupabaseService _supabase;
  final EncryptionService _encryption;

  Future<List<Vital>> getVitals(String patientId) async {
    final response = await _supabase.client
        .from('vitals')
        .select()
        .eq('patient_id', patientId)
        .order('recorded_at', ascending: false);

    return (response as List).map((json) => Vital.fromJson(json)).toList();
  }

  Future<void> addVital({
    required String patientId,
    required String type,
    required String value,
    required String unit,
    DateTime? recordedAt,
  }) async {
    // Encrypt the value before storing
    final encryptedValue = await _encryption.encryptMedicalRecord(
      data: value,
      biometricReason: 'Authenticate to log your health vitals',
    );

    await _supabase.client.from('vitals').insert({
      'patient_id': patientId,
      'type': type,
      'value': encryptedValue,
      'unit': unit,
      'recorded_at': (recordedAt ?? DateTime.now()).toIso8601String(),
    });
  }
}

final vitalsServiceProvider = Provider((ref) {
  return VitalsService(
    SupabaseService.instance,
    EncryptionService.instance,
  );
});
