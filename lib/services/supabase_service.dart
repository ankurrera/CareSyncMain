import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logging/app_logger.dart';
import 'emergency_audit_service.dart';
import 'secure_storage_service.dart';
import 'encryption_service.dart';

/// Singleton service for Supabase database operations
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  User? get currentUser => auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await auth.signUp(email: email, password: password, data: data);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUserId == null) return null;
    final response =
        await client
            .from('profiles')
            .select()
            .eq('id', currentUserId!)
            .maybeSingle();

    if (response == null) return null;

    final role = response['role'] as String?;
    if (role == 'doctor') {
      final docResponse =
          await client
              .from('doctors')
              .select(
                'license_number, specialization, hospital_affiliation, signature_base64, signature_hash',
              )
              .eq('user_id', currentUserId!)
              .maybeSingle();
      if (docResponse != null) {
        response['medical_registration_number'] = docResponse['license_number'];
        response['specialization'] = docResponse['specialization'];
        response['hospital_clinic_name'] = docResponse['hospital_affiliation'];

        // Sync signature base64 & hash dynamically
        final sig = docResponse['signature_base64'] as String?;
        final hash = docResponse['signature_hash'] as String?;
        if (sig != null && hash != null) {
          await SecureStorageService.instance.setDoctorSignature(sig);
          await SecureStorageService.instance.setDoctorSignatureHash(hash);
        }
      }
    } else if (role == 'pharmacist') {
      final pharmResponse =
          await client
              .from('pharmacists')
              .select('license_number, pharmacy_name, pharmacy_address')
              .eq('user_id', currentUserId!)
              .maybeSingle();
      if (pharmResponse != null) {
        response['license_number'] = pharmResponse['license_number'];
        response['pharmacy_name'] = pharmResponse['pharmacy_name'];
        response['pharmacy_address'] = pharmResponse['pharmacy_address'];
      }
    }

    return response;
  }

  Future<void> upsertProfile(Map<String, dynamic> data) async {
    final profileKeys = [
      'email',
      'phone',
      'full_name',
      'avatar_url',
      'role',
      'gender',
    ];
    final profileData = <String, dynamic>{
      'id': currentUserId,
      'updated_at': DateTime.now().toIso8601String(),
    };
    bool hasProfileUpdates = false;
    for (final key in profileKeys) {
      if (data.containsKey(key)) {
        profileData[key] = data[key];
        if (key != 'role') {
          hasProfileUpdates = true;
        }
      }
    }

    if (hasProfileUpdates) {
      await client.from('profiles').upsert(profileData);
    }

    final role =
        data['role'] ??
        (await client
                .from('profiles')
                .select('role')
                .eq('id', currentUserId!)
                .single())['role']
            as String?;

    if (role == 'doctor') {
      final doctorData = <String, dynamic>{'user_id': currentUserId};
      if (data.containsKey('hospital_clinic_name')) {
        doctorData['hospital_affiliation'] = data['hospital_clinic_name'];
      }
      if (data.containsKey('specialization')) {
        doctorData['specialization'] = data['specialization'];
      }
      if (data.containsKey('medical_registration_number')) {
        doctorData['license_number'] = data['medical_registration_number'];
      }
      if (doctorData.length > 1) {
        await client.from('doctors').upsert(doctorData, onConflict: 'user_id');
      }
    } else if (role == 'pharmacist') {
      final pharmacistData = <String, dynamic>{'user_id': currentUserId};
      if (data.containsKey('license_number')) {
        pharmacistData['license_number'] = data['license_number'];
      }
      if (data.containsKey('pharmacy_name')) {
        pharmacistData['pharmacy_name'] = data['pharmacy_name'];
      }
      if (data.containsKey('pharmacy_address')) {
        pharmacistData['pharmacy_address'] = data['pharmacy_address'];
      }
      if (pharmacistData.length > 1) {
        await client
            .from('pharmacists')
            .upsert(pharmacistData, onConflict: 'user_id');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  // ... inside SupabaseService class ...

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPatientData({String? userId}) async {
    final targetId = userId ?? currentUserId;
    if (targetId == null) return null;

    try {
      // FIX: Changed 'patient_data' to 'patients'
      var response =
          await client
              .from('patients')
              .select()
              .eq('user_id', targetId)
              .maybeSingle();

      if (response == null) {
        try {
          // FIX: Changed 'patient_data' to 'patients'
          response =
              await client
                  .from('patients')
                  .insert({'user_id': targetId})
                  .select()
                  .single();
        } catch (insertError) {
          // FIX: Changed 'patient_data' to 'patients'
          response =
              await client
                  .from('patients')
                  .select()
                  .eq('user_id', targetId)
                  .maybeSingle();
        }
      }

      return response;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPatientDataByPatientId(
    String patientId,
  ) async {
    if (patientId.isEmpty) return null;
    try {
      final response =
          await client
              .from('patients')
              .select('*, profiles(full_name, gender)')
              .eq('id', patientId)
              .maybeSingle();
      return response;
    } catch (e) {
      AppLogger.warning(
        'Error getting patient data by patientId',
        category: LogCategory.database,
        error: e,
      );
      return null;
    }
  }

  Future<void> upsertPatientData(
    Map<String, dynamic> data, {
    String? userId,
  }) async {
    final targetId = userId ?? currentUserId;
    if (targetId == null) return;

    // FIX: Changed 'patient_data' to 'patients' with explicit onConflict key
    await client.from('patients').upsert({
      'user_id': targetId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  /// Update face scan URL and embedding vector for the patient
  Future<void> updatePatientFaceEmbedding({
    required String faceScanUrl,
    required List<double> embedding,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    await client
        .from('patients')
        .update({
          'face_scan_url': faceScanUrl,
          'face_embedding': embedding,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STORAGE OPERATIONS (NEW)
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads a file to Supabase Storage and returns the Public URL
  Future<String?> uploadFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    try {
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = client.storage.from(bucket).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      AppLogger.warning(
        'Error uploading file',
        category: LogCategory.network,
        error: e,
      );
      return null;
    }
  }

  /// Generates a signed access URL for private prescription PDFs (valid for 10 min)
  Future<String?> getPrescriptionSignedUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.last;

      final signedUrl = await client.storage
          .from('prescriptions')
          .createSignedUrl(filename, 600);
      return signedUrl;
    } catch (e) {
      AppLogger.warning(
        'Error generating signed URL for prescription',
        category: LogCategory.network,
        error: e,
      );
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRESCRIPTION OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPatientPrescriptions(
    String patientId, {
    int limit = 20,
    int offset = 0,
  }) async {
    if (patientId.isEmpty) return [];
    final response = await client
        .from('prescriptions')
        .select('*, prescription_items(*), doctor:profiles!doctor_id(*)')
        .eq('patient_id', patientId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// NEW: Get prescriptions created by the current doctor in the last 3 days
  Future<List<Map<String, dynamic>>> getDoctorRecentPrescriptions() async {
    if (currentUserId == null) return [];

    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    // We join 'patients' to get the patient reference,
    // then nested join 'profiles' (via patient's user_id) to get the name.
    final response = await client
        .from('prescriptions')
        .select('''
          *,
          patient:patients!patient_id(
            id,
            user_id,
            profiles:profiles!user_id(full_name)
          )
        ''')
        .eq('doctor_id', currentUserId!)
        .gte('created_at', threeDaysAgo.toIso8601String())
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createPrescription({
    required String patientId,
    required String diagnosis,
    String? notes,
    bool isPublic = false,
    bool patientEntered = false,
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? metadata,
  }) async {
    final prescription =
        await client
            .from('prescriptions')
            .insert({
              'patient_id': patientId,
              'doctor_id': patientEntered ? null : currentUserId,
              'diagnosis': diagnosis,
              'notes': notes,
              'is_public': isPublic,
              'patient_entered': patientEntered,
              'metadata': metadata,
            })
            .select()
            .single();

    final prescriptionId = prescription['id'];
    for (final item in items) {
      await client.from('prescription_items').insert({
        'prescription_id': prescriptionId,
        ...item,
      });
    }

    return prescription;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DISPENSING & OTHER OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> recordDispensing({
    required String prescriptionId,
    required String patientId,
    String? notes,
    List<String>? itemsDispensed,
  }) async {
    final pharmacistId = currentUserId;
    if (pharmacistId == null) {
      throw Exception('User session is invalid. Cannot dispense.');
    }

    await client.rpc(
      'dispense_prescription_items_v1',
      params: {
        'p_prescription_id': prescriptionId,
        'p_pharmacist_id': pharmacistId,
        'p_patient_id': patientId,
        'p_item_ids': itemsDispensed ?? [],
        'p_notes': notes ?? '',
      },
    );
  }

  Future<Map<String, dynamic>?> getEmergencyData(String qrCodeId) async {
    final response = await client.rpc(
      'get_emergency_data',
      params: {'p_qr_code_id': qrCodeId},
    );

    if (response == null) {
      try {
        await EmergencyAuditService.instance.logQrScan(
          patientId: null,
          status: 'Failed',
        );
      } catch (_) {}
      return null;
    }

    final data = Map<String, dynamic>.from(response);
    final patient = data['patient'] as Map<String, dynamic>?;
    final patientId = patient?['id'] as String?;

    try {
      await EmergencyAuditService.instance.logQrScan(
        patientId: patientId,
        status: 'Success',
      );
    } catch (_) {}

    // Decrypt vitals values locally (they are returned as encrypted strings in vital objects)
    final vitalsRaw = data['vitals'] as Map<String, dynamic>? ?? {};
    final Map<String, Map<String, dynamic>> decryptedVitals = {};

    if (patientId != null) {
      vitalsRaw.forEach((type, v) {
        final valRaw = v as Map<String, dynamic>? ?? {};
        final valEnc = valRaw['value']?.toString() ?? '';
        String valDec = valEnc;
        try {
          valDec = EncryptionService.instance.decryptDeterministic(
            encryptedData: valEnc,
            patientId: patientId,
          );
        } catch (e) {
          AppLogger.warning(
            'Error decrypting vital in emergency',
            category: LogCategory.encryption,
            error: e,
          );
        }
        decryptedVitals[type] = {
          'value': valDec,
          'unit': valRaw['unit'],
          'recorded_at': valRaw['recorded_at'],
        };
      });
    }

    return {
      'patient': patient,
      'conditions': List<Map<String, dynamic>>.from(data['conditions'] ?? []),
      'medications': List<Map<String, dynamic>>.from(data['medications'] ?? []),
      'vitals': decryptedVitals,
      'physician': data['physician'] as Map<String, dynamic>?,
    };
  }

  Future<int> getTodaysPrescriptionCount() async {
    if (currentUserId == null) return 0;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final result = await client
        .from('prescriptions')
        .select('id')
        .eq('doctor_id', currentUserId!)
        .gte('created_at', startOfDay.toIso8601String());
    return (result as List).length;
  }

  Future<int> getTotalPrescriptionCount() async {
    if (currentUserId == null) return 0;
    final result = await client
        .from('prescriptions')
        .select('id')
        .eq('doctor_id', currentUserId!);
    return (result as List).length;
  }

  Future<int> getTodaysDispensingCount() async {
    if (currentUserId == null) return 0;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final result = await client
        .from('dispensing_records')
        .select('id')
        .eq('pharmacist_id', currentUserId!)
        .gte('dispensed_at', startOfDay.toIso8601String());
    return (result as List).length;
  }

  Future<void> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    await client.from('user_devices').insert({
      'user_id': currentUserId,
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'enrolled_at': DateTime.now().toIso8601String(),
      'last_used_at': DateTime.now().toIso8601String(),
      'is_active': true,
    });
  }
}
