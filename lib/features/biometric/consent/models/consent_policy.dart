/// Consent Policy model mapping the public.consent_records table
class ConsentPolicy {
  final String id;
  final String patientId;
  final String doctorId;
  final String consentType; // Single Session, Scheduled Appointment, Ongoing Care, Emergency Override
  final String status; // active, revoked, expired
  final DateTime grantedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String? authCodeHash;

  const ConsentPolicy({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.consentType,
    required this.status,
    required this.grantedAt,
    required this.expiresAt,
    this.revokedAt,
    this.authCodeHash,
  });

  factory ConsentPolicy.fromJson(Map<String, dynamic> json) {
    return ConsentPolicy(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String,
      consentType: json['consent_type'] as String,
      status: json['status'] as String? ?? 'active',
      grantedAt: DateTime.parse(json['granted_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      revokedAt: json['revoked_at'] != null ? DateTime.parse(json['revoked_at'] as String) : null,
      authCodeHash: json['auth_code_hash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'consent_type': consentType,
      'status': status,
      'granted_at': grantedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'auth_code_hash': authCodeHash,
    };
  }

  ConsentPolicy copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? consentType,
    String? status,
    DateTime? grantedAt,
    DateTime? expiresAt,
    DateTime? revokedAt,
    String? authCodeHash,
  }) {
    return ConsentPolicy(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      consentType: consentType ?? this.consentType,
      status: status ?? this.status,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      revokedAt: revokedAt ?? this.revokedAt,
      authCodeHash: authCodeHash ?? this.authCodeHash,
    );
  }
}
