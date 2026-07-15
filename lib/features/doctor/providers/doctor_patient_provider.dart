import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/vitals_service.dart';
import '../../patient/models/vital.dart';
import '../../patient/models/prescription.dart';
import '../../patient/models/patient_data.dart';
import '../../../services/encryption_service.dart';

part 'doctor_patient_provider.g.dart';

@riverpod
Future<PatientData?> doctorPatientData(
  DoctorPatientDataRef ref,
  String patientId,
) async {
  if (patientId.isEmpty) return null;
  final data = await SupabaseService.instance.getPatientDataByPatientId(
    patientId,
  );
  if (data == null) return null;
  return PatientData.fromJson(data);
}

@riverpod
Future<List<Vital>> doctorPatientVitals(
  DoctorPatientVitalsRef ref,
  String patientId,
) async {
  if (patientId.isEmpty) return [];
  return ref.read(vitalsServiceProvider).getVitals(patientId);
}

@riverpod
Future<List<Prescription>> doctorPatientPrescriptions(
  DoctorPatientPrescriptionsRef ref,
  String patientId,
) async {
  if (patientId.isEmpty) return [];
  final data = await SupabaseService.instance.getPatientPrescriptions(
    patientId,
  );
  return data.map((json) => Prescription.fromJson(json)).toList();
}

@riverpod
Future<List<MedicalCondition>> doctorPatientConditions(
  DoctorPatientConditionsRef ref,
  String patientId,
) async {
  if (patientId.isEmpty) return [];
  final response = await SupabaseService.instance.client
      .from('medical_conditions')
      .select()
      .eq('patient_id', patientId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => MedicalCondition.fromJson(json))
      .toList();
}

@riverpod
Future<List<Vital>> decryptedDoctorPatientVitals(
  DecryptedDoctorPatientVitalsRef ref,
  String patientId,
) async {
  if (patientId.isEmpty) return [];
  final vitals = await ref.watch(doctorPatientVitalsProvider(patientId).future);
  final list = <Vital>[];
  for (var v in vitals) {
    try {
      final val = await EncryptionService.instance.decryptMedicalRecord(
        encryptedData: v.value,
        patientId: patientId,
      );
      list.add(v.copyWith(value: val));
    } catch (e) {
      list.add(v.copyWith(value: 'Error'));
    }
  }
  return list;
}
