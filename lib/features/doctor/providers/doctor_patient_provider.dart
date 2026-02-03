import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../services/supabase_service.dart';
import '../../../services/vitals_service.dart';
import '../../../services/appointment_service.dart';
import '../../patient/models/vital.dart';
import '../../patient/models/prescription.dart';
import '../../patient/models/patient_data.dart';

part 'doctor_patient_provider.g.dart';

@riverpod
Future<PatientData?> doctorPatientData(DoctorPatientDataRef ref, String userId) async {
  final data = await SupabaseService.instance.getPatientData(userId: userId);
  if (data == null) return null;
  return PatientData.fromJson(data);
}

@riverpod
Future<List<Vital>> doctorPatientVitals(DoctorPatientVitalsRef ref, String patientId) async {
  return ref.read(vitalsServiceProvider).getVitals(patientId);
}

@riverpod
Future<List<Prescription>> doctorPatientPrescriptions(DoctorPatientPrescriptionsRef ref, String patientId) async {
  final data = await SupabaseService.instance.getPatientPrescriptions(patientId);
  return data.map((json) => Prescription.fromJson(json)).toList();
}

@riverpod
Future<List<MedicalCondition>> doctorPatientConditions(DoctorPatientConditionsRef ref, String patientId) async {
  final response = await SupabaseService.instance.client
      .from('medical_conditions')
      .select()
      .eq('patient_id', patientId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => MedicalCondition.fromJson(json))
      .toList();
}
