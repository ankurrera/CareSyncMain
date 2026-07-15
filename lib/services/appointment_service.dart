import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/shared/models/appointment.dart';
import 'supabase_service.dart';

class AppointmentService {
  AppointmentService(this._supabase);

  final SupabaseService _supabase;

  Future<List<DoctorAvailability>> getDoctorAvailability(
    String doctorId,
  ) async {
    final response = await _supabase.client
        .from('doctor_availability')
        .select()
        .eq('doctor_id', doctorId)
        .eq('is_active', true);

    return (response as List)
        .map((json) => DoctorAvailability.fromJson(json))
        .toList();
  }

  Future<void> setAvailability(List<Map<String, dynamic>> availability) async {
    final doctorId = _supabase.currentUserId;
    if (doctorId == null) return;

    for (var slot in availability) {
      await _supabase.client.from('doctor_availability').upsert({
        'doctor_id': doctorId,
        ...slot,
      });
    }
  }

  Map<String, dynamic> _flattenDoctorProfile(Map<String, dynamic> json) {
    final Map<String, dynamic> flattenedJson = Map<String, dynamic>.from(json);
    if (json['doctor'] != null) {
      final doctorProfile = Map<String, dynamic>.from(json['doctor'] as Map);
      final doctorMeta =
          doctorProfile['doctors'] as Map<String, dynamic>? ?? {};
      doctorProfile['specialization'] = doctorMeta['specialization'];
      doctorProfile['hospital_clinic_name'] =
          doctorMeta['hospital_affiliation'];
      doctorProfile['medical_registration_number'] =
          doctorMeta['license_number'];
      flattenedJson['doctor'] = doctorProfile;
    }
    return flattenedJson;
  }

  Future<List<Appointment>> getUpcomingAppointments(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase.client
        .from('appointments')
        .select(
          '*, patient:profiles!patient_id(*), doctor:profiles!doctor_id(*, doctors(*))',
        )
        .or('patient_id.eq.$userId,doctor_id.eq.$userId')
        .gte('start_time', DateTime.now().toIso8601String())
        .order('start_time', ascending: true)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map(
          (json) => Appointment.fromJson(
            _flattenDoctorProfile(json as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  Future<List<Appointment>> getPatientAppointmentsHistory(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _supabase.client
        .from('appointments')
        .select(
          '*, patient:profiles!patient_id(*), doctor:profiles!doctor_id(*, doctors(*))',
        )
        .eq('patient_id', userId)
        .order('start_time', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map(
          (json) => Appointment.fromJson(
            _flattenDoctorProfile(json as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  Future<List<Appointment>> getBookedAppointments(
    String doctorId,
    DateTime date,
  ) async {
    final startOfDay =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay =
        DateTime(
          date.year,
          date.month,
          date.day,
          23,
          59,
          59,
          999,
        ).toIso8601String();

    final response = await _supabase.client
        .from('appointments')
        .select()
        .eq('doctor_id', doctorId)
        .eq('status', 'scheduled')
        .gte('start_time', startOfDay)
        .lte('start_time', endOfDay);

    return (response as List)
        .map((json) => Appointment.fromJson(json))
        .toList();
  }

  Future<void> bookAppointment({
    required String doctorId,
    required DateTime startTime,
    String? notes,
  }) async {
    final patientId = _supabase.currentUserId;
    if (patientId == null) return;

    await _supabase.client.from('appointments').insert({
      'patient_id': patientId,
      'doctor_id': doctorId,
      'start_time': startTime.toIso8601String(),
      'notes': notes,
      'status': 'scheduled',
    });
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    await _supabase.client
        .from('appointments')
        .update({'status': status})
        .eq('id', id);
  }
}

final appointmentServiceProvider = Provider((ref) {
  return AppointmentService(SupabaseService.instance);
});
