import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_profile.dart';

part 'appointment.freezed.dart';
part 'appointment.g.dart';

@freezed
class Appointment with _$Appointment {
  const factory Appointment({
    required String id,
    @JsonKey(name: 'patient_id') required String patientId,
    @JsonKey(name: 'doctor_id') required String doctorId,
    @JsonKey(name: 'start_time') required DateTime startTime,
    @Default('scheduled') String status, // 'scheduled', 'completed', 'cancelled'
    String? notes,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    // Joined data
    UserProfile? patient,
    UserProfile? doctor,
  }) = _Appointment;

  factory Appointment.fromJson(Map<String, dynamic> json) => _$AppointmentFromJson(json);
}

@freezed
class DoctorAvailability with _$DoctorAvailability {
  const factory DoctorAvailability({
    required String id,
    @JsonKey(name: 'doctor_id') required String doctorId,
    @JsonKey(name: 'day_of_week') required int dayOfWeek, // 0-6
    @JsonKey(name: 'start_time') required String startTime, // HH:mm:ss
    @JsonKey(name: 'end_time') required String endTime, // HH:mm:ss
    @Default(true) @JsonKey(name: 'is_active') bool isActive,
  }) = _DoctorAvailability;

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) => _$DoctorAvailabilityFromJson(json);
}
