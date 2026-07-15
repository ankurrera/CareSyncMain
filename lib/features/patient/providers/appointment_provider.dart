import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    // Subscribe to realtime Postgres changes for appointments
    final channel = SupabaseService.instance.client
        .channel('appointments_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: (payload) {
            ref.invalidateSelf();
          },
        );

    channel.subscribe();

    ref.onDispose(() {
      SupabaseService.instance.client.removeChannel(channel);
    });

    return ref.read(appointmentServiceProvider).getUpcomingAppointments(userId);
  }

  Future<void> book({
    required String doctorId,
    required DateTime startTime,
    String? notes,
  }) async {
    await ref
        .read(appointmentServiceProvider)
        .bookAppointment(
          doctorId: doctorId,
          startTime: startTime,
          notes: notes,
        );
    ref.invalidateSelf();
  }

  Future<void> cancel(String appointmentId) async {
    await ref
        .read(appointmentServiceProvider)
        .updateAppointmentStatus(appointmentId, 'cancelled');
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
Future<List<DoctorAvailability>> doctorAvailability(
  DoctorAvailabilityRef ref,
  String doctorId,
) async {
  return ref.read(appointmentServiceProvider).getDoctorAvailability(doctorId);
}

@riverpod
Future<List<Appointment>> bookedAppointments(
  BookedAppointmentsRef ref, {
  required String doctorId,
  required DateTime date,
}) async {
  final channel = SupabaseService.instance.client
      .channel(
        'booked_appointments_${doctorId}_${date.year}_${date.month}_${date.day}',
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'appointments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'doctor_id',
          value: doctorId,
        ),
        callback: (payload) {
          ref.invalidateSelf();
        },
      );

  channel.subscribe();
  ref.onDispose(() {
    SupabaseService.instance.client.removeChannel(channel);
  });

  return ref
      .read(appointmentServiceProvider)
      .getBookedAppointments(doctorId, date);
}

@riverpod
Future<List<UserProfile>> patientDoctors(PatientDoctorsRef ref) async {
  final userId = SupabaseService.instance.currentUserId;
  if (userId == null) return [];

  // Watch Appointments state to automatically trigger updates on new bookings/status changes
  ref.watch(appointmentsProvider);

  final appointments = await ref
      .read(appointmentServiceProvider)
      .getPatientAppointmentsHistory(userId);

  // Extract unique doctors
  final uniqueDoctors = <String, UserProfile>{};
  for (final appt in appointments) {
    if (appt.doctor != null) {
      uniqueDoctors[appt.doctor!.id] = appt.doctor!;
    }
  }

  return uniqueDoctors.values.toList();
}
