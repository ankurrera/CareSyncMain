/// User profile model
class UserProfile {
  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? gender; // Added
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Doctor Specific Fields
  final String? hospitalName;
  final String? specialization;
  final String? medicalRegNumber;

  // Pharmacist Specific Fields
  final String? licenseNumber;
  final String? pharmacyName;
  final String? pharmacyAddress;

  const UserProfile({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.gender, // Added
    required this.createdAt,
    this.updatedAt,
    this.hospitalName,
    this.specialization,
    this.medicalRegNumber,
    this.licenseNumber,
    this.pharmacyName,
    this.pharmacyAddress,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as String?, // Added
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      hospitalName: json['hospital_clinic_name'] as String?,
      specialization: json['specialization'] as String?,
      medicalRegNumber: json['medical_registration_number'] as String?,
      licenseNumber: json['license_number'] as String?,
      pharmacyName: json['pharmacy_name'] as String?,
      pharmacyAddress: json['pharmacy_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'gender': gender, // Added
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'hospital_clinic_name': hospitalName,
      'specialization': specialization,
      'medical_registration_number': medicalRegNumber,
      'license_number': licenseNumber,
      'pharmacy_name': pharmacyName,
      'pharmacy_address': pharmacyAddress,
    };
  }

  bool get isPatient => role == 'patient';
  bool get isDoctor => role == 'doctor';
  bool get isPharmacist => role == 'pharmacist';
  bool get isFirstResponder => role == 'first_responder';

  String get roleDisplayName {
    switch (role) {
      case 'patient':
        return 'Patient';
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'first_responder':
        return 'First Responder';
      default:
        return role;
    }
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    String? role,
    String? avatarUrl,
    String? gender, // Added
    DateTime? createdAt,
    DateTime? updatedAt,
    String? hospitalName,
    String? specialization,
    String? medicalRegNumber,
    String? licenseNumber,
    String? pharmacyName,
    String? pharmacyAddress,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender, // Added
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hospitalName: hospitalName ?? this.hospitalName,
      specialization: specialization ?? this.specialization,
      medicalRegNumber: medicalRegNumber ?? this.medicalRegNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyAddress: pharmacyAddress ?? this.pharmacyAddress,
    );
  }
}