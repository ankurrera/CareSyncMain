import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/vital.dart';
import '../../../services/vitals_service.dart';
import '../../../services/supabase_service.dart';

part 'vitals_provider.g.dart';

@riverpod
class PatientVitals extends _$PatientVitals {
  @override
  FutureOr<List<Vital>> build() async {
    final patientId = await _getPatientId();
    if (patientId == null) return [];
    
    return ref.read(vitalsServiceProvider).getVitals(patientId);
  }

  Future<String?> _getPatientId() async {
    final supabase = SupabaseService.instance;
    final patientData = await supabase.getPatientData();
    return patientData?['id'] as String?;
  }

  Future<void> addVital({
    required VitalType type,
    required String value,
    required String unit,
    DateTime? recordedAt,
  }) async {
    final patientId = await _getPatientId();
    if (patientId == null) return;

    await ref.read(vitalsServiceProvider).addVital(
      patientId: patientId,
      type: type.name.replaceAll(' ', '_').toLowerCase(),
      value: value,
      unit: unit,
      recordedAt: recordedAt,
    );

    ref.invalidateSelf();
  }
}

@riverpod
Future<List<Vital>> filteredVitals(FilteredVitalsRef ref, String type) async {
  final allVitals = await ref.watch(patientVitalsProvider.future);
  if (type == 'all') return allVitals;
  return allVitals.where((v) => v.type == type).toList();
}
