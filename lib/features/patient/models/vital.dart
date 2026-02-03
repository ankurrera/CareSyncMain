import 'package:freezed_annotation/freezed_annotation.dart';

part 'vital.freezed.dart';
part 'vital.g.dart';

@freezed
class Vital with _$Vital {
  const factory Vital({
    required String id,
    @JsonKey(name: 'patient_id') required String patientId,
    required String type, // 'blood_pressure', 'glucose', 'weight', 'heart_rate'
    required String value, // Encrypted Base64 string
    required String unit,
    @JsonKey(name: 'recorded_at') required DateTime recordedAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _Vital;

  factory Vital.fromJson(Map<String, dynamic> json) => _$VitalFromJson(json);
}

enum VitalType {
  @JsonValue('blood_pressure') bloodPressure,
  @JsonValue('glucose') glucose,
  @JsonValue('weight') weight,
  @JsonValue('heart_rate') heartRate,
}

extension VitalTypeExtension on VitalType {
  String get name {
    switch (this) {
      case VitalType.bloodPressure: return 'Blood Pressure';
      case VitalType.glucose: return 'Glucose';
      case VitalType.weight: return 'Weight';
      case VitalType.heartRate: return 'Heart Rate';
    }
  }

  String get unit {
    switch (this) {
      case VitalType.bloodPressure: return 'mmHg';
      case VitalType.glucose: return 'mg/dL';
      case VitalType.weight: return 'kg';
      case VitalType.heartRate: return 'bpm';
    }
  }
}
