/// Biometric Profile Model mapping the public.biometric_profiles table
class BiometricProfile {
  final String id;
  final String userId;
  final String enrollmentStatus;
  final double livenessScoreThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BiometricProfile({
    required this.id,
    required this.userId,
    required this.enrollmentStatus,
    required this.livenessScoreThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BiometricProfile.fromJson(Map<String, dynamic> json) {
    return BiometricProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      enrollmentStatus: json['enrollment_status'] as String? ?? 'unverified',
      livenessScoreThreshold:
          (json['liveness_score_threshold'] as num? ?? 0.90).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'enrollment_status': enrollmentStatus,
      'liveness_score_threshold': livenessScoreThreshold,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BiometricProfile copyWith({
    String? id,
    String? userId,
    String? enrollmentStatus,
    double? livenessScoreThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BiometricProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      livenessScoreThreshold:
          livenessScoreThreshold ?? this.livenessScoreThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
