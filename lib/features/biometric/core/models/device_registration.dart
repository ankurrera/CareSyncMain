/// Device Registration model mapping the public.device_trust table
class DeviceRegistration {
  final String id;
  final String userId;
  final String deviceId;
  final String? deviceName;
  final String? deviceOs;
  final String tokenFingerprintHash;
  final bool isActive;
  final DateTime enrolledAt;
  final DateTime lastUsedAt;

  const DeviceRegistration({
    required this.id,
    required this.userId,
    required this.deviceId,
    this.deviceName,
    this.deviceOs,
    required this.tokenFingerprintHash,
    required this.isActive,
    required this.enrolledAt,
    required this.lastUsedAt,
  });

  factory DeviceRegistration.fromJson(Map<String, dynamic> json) {
    return DeviceRegistration(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String?,
      deviceOs: json['device_os'] as String?,
      tokenFingerprintHash: json['token_fingerprint_hash'] as String,
      isActive: json['is_active'] as bool? ?? true,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_os': deviceOs,
      'token_fingerprint_hash': tokenFingerprintHash,
      'is_active': isActive,
      'enrolled_at': enrolledAt.toIso8601String(),
      'last_used_at': lastUsedAt.toIso8601String(),
    };
  }

  DeviceRegistration copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    String? deviceOs,
    String? tokenFingerprintHash,
    bool? isActive,
    DateTime? enrolledAt,
    DateTime? lastUsedAt,
  }) {
    return DeviceRegistration(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceOs: deviceOs ?? this.deviceOs,
      tokenFingerprintHash: tokenFingerprintHash ?? this.tokenFingerprintHash,
      isActive: isActive ?? this.isActive,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
