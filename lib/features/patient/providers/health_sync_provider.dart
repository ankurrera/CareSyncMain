import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

import '../../../services/encryption_service.dart';
import '../../../services/supabase_service.dart';
import 'vitals_provider.dart';

import '../../../../services/wearables/health_platform_adapter.dart';
import '../../../../services/wearables/wearable_service.dart';
import '../../../../services/wearables/offline_sync_queue.dart';
import '../../../../services/wearables/conflict_resolver.dart';

class HealthSyncState {
  final Set<String>
  connectedSources; // 'whoop', 'apple_health', 'google_fit', 'fitbit', 'garmin'
  final int liveHeartRate;
  final String liveBloodPressure;
  final double liveWeight;
  final bool isSyncing;
  final String? lastSyncTime;
  final String? syncError;

  HealthSyncState({
    required this.connectedSources,
    required this.liveHeartRate,
    required this.liveBloodPressure,
    required this.liveWeight,
    required this.isSyncing,
    this.lastSyncTime,
    this.syncError,
  });

  HealthSyncState copyWith({
    Set<String>? connectedSources,
    int? liveHeartRate,
    String? liveBloodPressure,
    double? liveWeight,
    bool? isSyncing,
    String? lastSyncTime,
    String? syncError,
  }) {
    return HealthSyncState(
      connectedSources: connectedSources ?? this.connectedSources,
      liveHeartRate: liveHeartRate ?? this.liveHeartRate,
      liveBloodPressure: liveBloodPressure ?? this.liveBloodPressure,
      liveWeight: liveWeight ?? this.liveWeight,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncError: syncError ?? this.syncError,
    );
  }
}

class HealthSyncNotifier extends StateNotifier<HealthSyncState> {
  final Ref _ref;
  Timer? _pollingTimer;

  HealthSyncNotifier(this._ref)
    : super(
        HealthSyncState(
          connectedSources: {},
          liveHeartRate: 0,
          liveBloodPressure: 'Not Available',
          liveWeight: 0.0,
          isSyncing: false,
          lastSyncTime: 'Never',
        ),
      );

  Future<void> connectPlatformSource(String source) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final authorized =
          await HealthPlatformAdapter.instance.requestPermissions();
      if (authorized) {
        state = state.copyWith(
          connectedSources: {...state.connectedSources, source},
        );
        await syncLiveVitals();
        _startPolling();
      } else {
        state = state.copyWith(syncError: 'Permissions denied by user');
      }
    } catch (e) {
      state = state.copyWith(syncError: 'Connection failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> connectOAuthSource(String source) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      await WearableService.instance.initiateOAuth(source);
      // Once OAuth callback redirects, handleCallbackRedirect will add it to active sources.
    } catch (e) {
      state = state.copyWith(syncError: 'OAuth initialization failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> completeOAuthConnection(String source, String code) async {
    state = state.copyWith(isSyncing: true, syncError: null);
    try {
      final success = await WearableService.instance.handleCallbackRedirect(
        source,
        code,
      );
      if (success) {
        state = state.copyWith(
          connectedSources: {...state.connectedSources, source},
        );
        await syncLiveVitals();
        _startPolling();
      } else {
        state = state.copyWith(syncError: 'OAuth authentication failed');
      }
    } catch (e) {
      state = state.copyWith(syncError: 'OAuth connection failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> disconnectSource(String source) async {
    final updated = Set<String>.from(state.connectedSources)..remove(source);
    state = state.copyWith(connectedSources: updated);

    if (source != 'apple_health' && source != 'google_fit') {
      await WearableService.instance.revokeTokens(source);
    }

    if (updated.isEmpty) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncLiveVitals(),
    );
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> syncLiveVitals() async {
    if (state.connectedSources.isEmpty) return;
    state = state.copyWith(isSyncing: true, syncError: null);

    try {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 1));

      // 1. Process Offline Queue first if we have network connectivity
      await _flushOfflineQueue();

      // 2. Fetch Native Health Data (HealthKit / Health Connect)
      if (state.connectedSources.contains('apple_health') ||
          state.connectedSources.contains('google_fit')) {
        final List<HealthDataPoint> points = await HealthPlatformAdapter
            .instance
            .fetchVitals(startTime, now);
        await _processPlatformPoints(points);
      }

      // 3. Fetch Fitbit Web Data
      if (state.connectedSources.contains('fitbit')) {
        final list = await WearableService.instance.fetchFitbitHeartRate();
        for (var item in list) {
          await _uploadOrQueueVital(
            type: 'heart_rate',
            value: item['value'] as String,
            unit: item['unit'] as String,
            recordedAt: DateTime.parse(item['recorded_at'] as String),
            sourceName: 'fitbit',
            deviceName: item['device_name'] as String,
            duplicateHash: item['duplicate_hash'] as String,
          );
        }
      }

      state = state.copyWith(
        lastSyncTime: '${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      state = state.copyWith(syncError: 'Sync failed: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> _processPlatformPoints(List<HealthDataPoint> points) async {
    int latestHr = state.liveHeartRate;
    double latestWeight = state.liveWeight;
    String latestBp = state.liveBloodPressure;

    for (var point in points) {
      final valueStr = point.value.toString();
      final recordedAt = point.dateFrom;
      final typeStr = _mapHealthType(point.type);
      final unitStr = point.unit.name;
      final deviceName = point.sourceName;
      final deviceId = point.sourceId;

      if (typeStr == null) continue;

      final patientId = await _getPatientId();
      if (patientId == null) continue;

      final duplicateHash = ConflictResolver.instance.generateDuplicateHash(
        patientId: patientId,
        type: typeStr,
        value: valueStr,
        recordedAt: recordedAt.toIso8601String(),
      );

      // Save locally or remote
      await _uploadOrQueueVital(
        type: typeStr,
        value: valueStr,
        unit: unitStr,
        recordedAt: recordedAt,
        sourceName: 'native_platform',
        deviceName: deviceName,
        deviceId: deviceId,
        duplicateHash: duplicateHash,
      );

      // Keep track of the latest readings in memory to display on cards
      if (point.type == HealthDataType.HEART_RATE) {
        final val = double.tryParse(valueStr)?.round();
        if (val != null) latestHr = val;
      } else if (point.type == HealthDataType.WEIGHT) {
        final val = double.tryParse(valueStr);
        if (val != null) latestWeight = val;
      }
    }

    state = state.copyWith(
      liveHeartRate: latestHr,
      liveWeight: latestWeight,
      liveBloodPressure: latestBp,
    );
  }

  Future<void> _uploadOrQueueVital({
    required String type,
    required String value,
    required String unit,
    required DateTime recordedAt,
    required String sourceName,
    String? deviceName,
    String? deviceId,
    required String duplicateHash,
  }) async {
    final patientId = await _getPatientId();
    if (patientId == null) return;

    // Encrypt vital reading value
    final encryptedValue = await EncryptionService.instance
        .encryptMedicalRecord(
          data: value,
          biometricReason: 'Secure upload of wearable biometrics',
        );

    final vitalMap = {
      'patient_id': patientId,
      'type': type,
      'value': encryptedValue,
      'unit': unit,
      'recorded_at': recordedAt.toIso8601String(),
      'source': sourceName,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'device_name': deviceName,
      'device_id': deviceId,
      'confidence': 1.0,
      'duplicate_hash': duplicateHash,
    };

    try {
      // Test internet connectivity by querying Supabase
      final supabase = SupabaseService.instance;
      await supabase.client.from('vitals').insert(vitalMap);
      _ref.invalidate(patientVitalsProvider);
    } catch (_) {
      // Enqueue locally if offline or connection fails
      await OfflineSyncQueue.instance.enqueueVital(vitalMap);
    }
  }

  Future<void> _flushOfflineQueue() async {
    final queued = await OfflineSyncQueue.instance.getQueuedVitals();
    if (queued.isEmpty) return;

    final supabase = SupabaseService.instance;
    for (var row in queued) {
      try {
        final map = Map<String, dynamic>.from(row)..remove('id');
        await supabase.client.from('vitals').insert(map);
        await OfflineSyncQueue.instance.removeVital(row['id'] as int);
      } catch (_) {
        // If still offline, stop flushing
        break;
      }
    }
    _ref.invalidate(patientVitalsProvider);
  }

  String? _mapHealthType(HealthDataType type) {
    switch (type) {
      case HealthDataType.HEART_RATE:
        return 'heart_rate';
      case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
      case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        return 'blood_pressure';
      case HealthDataType.WEIGHT:
        return 'weight';
      default:
        return null;
    }
  }

  Future<String?> _getPatientId() async {
    final supabase = SupabaseService.instance;
    final patientData = await supabase.getPatientData();
    return patientData?['id'] as String?;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final healthSyncProvider =
    StateNotifierProvider<HealthSyncNotifier, HealthSyncState>((ref) {
      return HealthSyncNotifier(ref);
    });
