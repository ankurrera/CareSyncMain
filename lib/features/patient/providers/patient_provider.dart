import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../services/kyc_service.dart';
import '../models/patient_data.dart';
import '../models/prescription.dart';

/// Provider to check if KYC is verified
/// Checks the ACTIVE profile's status implicitly via the service
final isKycVerifiedProvider = FutureProvider<bool>((ref) async {
  final kyc = await ref.watch(kycStatusProvider.future);
  return kyc?.status == KYCStatus.verified;
});

/// Provider for current patient data - tied to the authenticated user
final patientDataProvider = FutureProvider<PatientData?>((ref) async {
  // Watch the currently authenticated user
  final activeId = ref.watch(authStateProvider).valueOrNull?.id;
  if (activeId == null) return null;

  // FIX: This now triggers the updated getPatientData which creates missing records
  final data = await SupabaseService.instance.getPatientData(userId: activeId);
  if (data == null) return null;
  return PatientData.fromJson(data);
});

/// Provider for patient prescriptions
final patientPrescriptionsProvider = FutureProvider<List<Prescription>>((
  ref,
) async {
  final patientData = await ref.watch(patientDataProvider.future);
  if (patientData == null) return [];

  final channel = SupabaseService.instance.client
      .channel('patient_prescriptions_${patientData.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'prescriptions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'patient_id',
          value: patientData.id,
        ),
        callback: (payload) {
          ref.invalidateSelf();
        },
      );

  channel.subscribe();
  ref.onDispose(() {
    SupabaseService.instance.client.removeChannel(channel);
  });

  final data = await SupabaseService.instance.getPatientPrescriptions(
    patientData.id,
  );
  return data.map((json) => Prescription.fromJson(json)).toList();
});

/// Computed Provider for active prescriptions only
final activePrescriptionsProvider = Provider<AsyncValue<List<Prescription>>>((
  ref,
) {
  final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);
  return prescriptionsAsync.whenData(
    (list) => list.where((p) => p.isActive).toList(),
  );
});

/// Computed Provider for today's active medication items (medication checklist)
final todayMedicationsProvider = Provider<AsyncValue<List<PrescriptionItem>>>((
  ref,
) {
  final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);
  return prescriptionsAsync.whenData((prescriptions) {
    final List<PrescriptionItem> items = [];
    for (final p in prescriptions) {
      for (final item in p.items) {
        if (item.isDispensed) {
          items.add(item);
        }
      }
    }
    return items;
  });
});

/// Provider for medical conditions - KYC verification required
final medicalConditionsProvider = FutureProvider<List<MedicalCondition>>((
  ref,
) async {
  // Check KYC status first (of the logged in user who is viewing)
  final isKycVerified = await ref.watch(isKycVerifiedProvider.future);
  if (!isKycVerified) {
    throw KYCRequiredException(
      'KYC verification required to access medical records',
    );
  }

  final patientData = await ref.watch(patientDataProvider.future);
  if (patientData == null) return [];

  final response = await SupabaseService.instance.client
      .from('medical_conditions')
      .select()
      .eq('patient_id', patientData.id)
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => MedicalCondition.fromJson(json))
      .toList();
});

/// Notifier for managing patient data
class PatientNotifier extends StateNotifier<AsyncValue<PatientData?>> {
  final String? activeUserId;

  PatientNotifier(this.activeUserId) : super(const AsyncValue.loading()) {
    _loadPatient();
  }

  final _supabase = SupabaseService.instance;

  Future<void> _loadPatient() async {
    try {
      if (activeUserId == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final data = await _supabase.getPatientData(userId: activeUserId);
      if (data == null) {
        state = const AsyncValue.data(null);
        return;
      }
      state = AsyncValue.data(PatientData.fromJson(data));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePatientData({
    String? bloodType,
    DateTime? dateOfBirth,
    Map<String, String>? emergencyContact,
  }) async {
    try {
      if (activeUserId == null) return;

      await _supabase.upsertPatientData({
        if (bloodType != null) 'blood_type': bloodType,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
        if (emergencyContact != null) 'emergency_contact': emergencyContact,
      }, userId: activeUserId);

      await _loadPatient();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addMedicalCondition({
    required String conditionType,
    required String description,
    String? severity,
    bool isPublic = true,
  }) async {
    try {
      final patientData = state.valueOrNull;
      if (patientData == null) return;

      await _supabase.client.from('medical_conditions').insert({
        'patient_id': patientData.id,
        'condition_type': conditionType,
        'description': description,
        'severity': severity,
        'is_public': isPublic,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleConditionVisibility(
    String conditionId,
    bool isPublic,
  ) async {
    try {
      await _supabase.client
          .from('medical_conditions')
          .update({'is_public': isPublic})
          .eq('id', conditionId);
    } catch (e) {
      rethrow;
    }
  }
}

// autoDispose ensures this notifier rebuilds/resets when the authenticated user changes
final patientNotifierProvider = StateNotifierProvider.autoDispose<
  PatientNotifier,
  AsyncValue<PatientData?>
>((ref) {
  final activeId = ref.watch(authStateProvider).valueOrNull?.id;
  return PatientNotifier(activeId);
});
