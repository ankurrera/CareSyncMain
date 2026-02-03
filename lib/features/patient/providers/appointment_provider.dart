import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../shared/models/appointment.dart';
import '../../shared/models/user_profile.dart';
import '../../../services/appointment_service.dart';
import '../../../services/supabase_service.dart';

part 'appointment_provider.g.dart';

@riverpod
class Appointments extends _$Appointments {
  @override
  FutureOr<List<Appointment>> build() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];
    
    return ref.read(appointmentServiceProvider).getUpcomingAppointments(userId);
  }

  Future<void> book({
    required String doctorId,
    required DateTime startTime,
    String? notes,
  }) async {
    await ref.read(appointmentServiceProvider).bookAppointment(
      doctorId: doctorId,
      startTime: startTime,
      notes: notes,
    );
    ref.invalidateSelf();
  }

  Future<void> cancel(String appointmentId) async {
    await ref.read(appointmentServiceProvider).updateAppointmentStatus(appointmentId, 'cancelled');
    ref.invalidateSelf();
  }
}

@riverpod
Future<List<UserProfile>> availableDoctors(AvailableDoctorsRef ref) async {
  final supabase = SupabaseService.instance;
  // Join profiles with the doctors table to get specialization, etc.
  final response = await supabase.client
      .from('profiles')
      .select('*, doctors(*)')
      .eq('role', 'doctor');
  
  return (response as List).map((json) {
    // Supabase returns the joined 'doctors' record as a Map for one-to-one relationships
    final doctorMeta = json['doctors'] as Map<String, dynamic>? ?? {};

    // Flatten doctor metadata into the profile object for UserProfile.fromJson
    final Map<String, dynamic> flattened = Map<String, dynamic>.from(json);
    flattened['specialization'] = doctorMeta['specialization'];
    flattened['hospital_clinic_name'] = doctorMeta['hospital_affiliation'];
    flattened['medical_registration_number'] = doctorMeta['license_number'];

    return UserProfile.fromJson(flattened);
  }).toList();
}

@riverpod
Future<List<DoctorAvailability>> doctorAvailability(DoctorAvailabilityRef ref, String doctorId) async {
  return ref.read(appointmentServiceProvider).getDoctorAvailability(doctorId);
}
