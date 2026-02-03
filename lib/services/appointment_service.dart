import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/shared/models/appointment.dart';
import 'supabase_service.dart';

class AppointmentService {
  AppointmentService(this._supabase);

  final SupabaseService _supabase;

  Future<List<DoctorAvailability>> getDoctorAvailability(String doctorId) async {
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

  Future<List<Appointment>> getUpcomingAppointments(String userId) async {
    final response = await _supabase.client
        .from('appointments')
        .select('*, patient:profiles!patient_id(*), doctor:profiles!doctor_id(*)')
        .or('patient_id.eq.$userId,doctor_id.eq.$userId')
        .gte('start_time', DateTime.now().toIso8601String())
        .order('start_time', ascending: true);

    return (response as List).map((json) => Appointment.fromJson(json)).toList();
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
