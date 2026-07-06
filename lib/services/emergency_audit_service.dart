import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'device_service.dart';
import 'secure_storage_service.dart';

/// Hospital-grade Emergency Access Audit Service
class EmergencyAuditService {
  EmergencyAuditService._();
  static final EmergencyAuditService instance = EmergencyAuditService._();

  final _supabase = Supabase.instance.client;
  final _storage = SecureStorageService.instance;
  final _device = DeviceService.instance;
  final _uuid = const Uuid();

  /// Logs a Face Recognition lookup
  Future<void> logFaceScan({
    String? patientId,
    required String status, // 'Success', 'Failed', 'Denied'
    required double confidence,
    String? reason,
    String? viewScope,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    final logId = _uuid.v4();

    // Fetch user details for current authenticated session
    String accessedByName = 'Unknown First Responder';
    String accessedByRole = 'unknown';
    String? hospitalName;
    String? orgName;

    if (currentUser != null) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name, role, hospital_clinic_name')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (profile != null) {
          accessedByName = profile['full_name'] ?? 'Unknown Provider';
          accessedByRole = profile['role'] ?? 'unknown';
          hospitalName = profile['hospital_clinic_name'];
          orgName = hospitalName;
        }
      } catch (_) {}
    }

    // Get device info
    String? devId;
    String? devName;
    String? devPlatform;
    try {
      final info = await _device.getDeviceInfo();
      devId = info.deviceId;
      devName = info.deviceName;
      devPlatform = info.platform;
    } catch (_) {}

    // Get location & IP (attempting public geocoding API, fallback to Geolocator)
    final locData = await _getLocationData();

    final logPayload = {
      'id': logId,
      'patient_id': patientId,
      'accessed_by_user_id': currentUser?.id,
      'accessed_by_name': accessedByName,
      'accessed_by_role': accessedByRole,
      'hospital_name': hospitalName,
      'organization_name': orgName,
      'device_id': devId,
      'device_name': devName,
      'device_platform': devPlatform,
      'authentication_method': 'Face Recognition',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': locData['latitude'],
      'longitude': locData['longitude'],
      'city': locData['city'],
      'state': locData['state'],
      'country': locData['country'],
      'ip_address': locData['ip_address'],
      'confidence_score': confidence,
      'access_status': status,
      'reason_for_access': reason ?? 'Emergency Treatment',
      'view_scope': viewScope ?? (status == 'Success' ? 'Emergency Summary' : 'Emergency ID Only'),
    };

    await _saveOrQueueLog(logPayload);
  }

  /// Logs a QR Code scan
  Future<void> logQrScan({
    required String patientId,
    required String status, // 'Success', 'Failed'
    String? viewScope,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    final logId = _uuid.v4();

    String accessedByName = 'Anonymous First Responder';
    String accessedByRole = 'unknown';
    String? hospitalName;
    String? orgName;

    if (currentUser != null) {
      try {
        final profile = await _supabase
            .from('profiles')
            .select('full_name, role, hospital_clinic_name')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (profile != null) {
          accessedByName = profile['full_name'] ?? 'Unknown Provider';
          accessedByRole = profile['role'] ?? 'unknown';
          hospitalName = profile['hospital_clinic_name'];
          orgName = hospitalName;
        }
      } catch (_) {}
    }

    String? devId;
    String? devName;
    String? devPlatform;
    try {
      final info = await _device.getDeviceInfo();
      devId = info.deviceId;
      devName = info.deviceName;
      devPlatform = info.platform;
    } catch (_) {}

    final locData = await _getLocationData();

    final logPayload = {
      'id': logId,
      'patient_id': patientId,
      'accessed_by_user_id': currentUser?.id,
      'accessed_by_name': accessedByName,
      'accessed_by_role': accessedByRole,
      'hospital_name': hospitalName,
      'organization_name': orgName,
      'device_id': devId,
      'device_name': devName,
      'device_platform': devPlatform,
      'authentication_method': 'QR Code',
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': locData['latitude'],
      'longitude': locData['longitude'],
      'city': locData['city'],
      'state': locData['state'],
      'country': locData['country'],
      'ip_address': locData['ip_address'],
      'access_status': status,
      'reason_for_access': 'Emergency Treatment',
      'view_scope': viewScope ?? (status == 'Success' ? 'Emergency ID Only' : 'Emergency ID Only'),
    };

    await _saveOrQueueLog(logPayload);
  }

  /// Internal: fetch geolocation and IP address
  Future<Map<String, dynamic>> _getLocationData() async {
    final Map<String, dynamic> result = {
      'latitude': null,
      'longitude': null,
      'city': 'Unknown',
      'state': 'Unknown',
      'country': 'Unknown',
      'ip_address': null,
    };

    // 1. Try public IP Geolocator lookup
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        result['ip_address'] = data['ip'];
        result['latitude'] = data['latitude'] as double?;
        result['longitude'] = data['longitude'] as double?;
        result['city'] = data['city'] ?? 'Unknown';
        result['state'] = data['region'] ?? 'Unknown';
        result['country'] = data['country_name'] ?? 'Unknown';
        return result;
      }
    } catch (_) {}

    // 2. Fallback: Try native GPS Geolocator if permissions exist
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 2),
          ),
        );
        result['latitude'] = position.latitude;
        result['longitude'] = position.longitude;
      }
    } catch (_) {}

    return result;
  }

  /// Internal: save immediately or add to offline queue
  Future<void> _saveOrQueueLog(Map<String, dynamic> logPayload) async {
    try {
      await _supabase.from('emergency_access_logs').insert(logPayload);
      // Success! Attempt background flush of previous queue items
      await flushQueue();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isOffline = errStr.contains('socketexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('handshake_status_server_error');

      if (isOffline) {
        debugPrint('[AUDIT] Device offline. Storing log to keychain queue.');
        final queue = await _storage.getQueuedLogs();
        // Avoid duplicate logging of same ID
        final exists = queue.any((item) => item['id'] == logPayload['id']);
        if (!exists) {
          queue.add(logPayload);
          await _storage.saveQueuedLogs(queue);
        }
      } else {
        debugPrint('[AUDIT] Failed to save database log directly: $e');
      }
    }
  }

  /// background sync logic: flushes all stored offline logs
  Future<void> flushQueue() async {
    final queue = await _storage.getQueuedLogs();
    if (queue.isEmpty) return;

    debugPrint('[AUDIT] Online. Flushing ${queue.length} queued logs.');
    final failedToSync = <Map<String, dynamic>>[];

    for (final log in queue) {
      try {
        await _supabase.from('emergency_access_logs').insert(log);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final remainsOffline = errStr.contains('socketexception') ||
            errStr.contains('failed host lookup');
        if (remainsOffline) {
          failedToSync.add(log);
        } else {
          // Discard bad logs that violate database schemas rather than re-queueing forever
          debugPrint('[AUDIT] Dropping malformed log: $e');
        }
      }
    }

    await _storage.saveQueuedLogs(failedToSync);
  }
}
