import 'dart:io';
import 'package:health/health.dart';

class HealthPlatformAdapter {
  HealthPlatformAdapter._privateConstructor() {
    // Configure Health Connect on Android
    if (Platform.isAndroid) {
      Health().configure();
    }
  }

  static final HealthPlatformAdapter instance =
      HealthPlatformAdapter._privateConstructor();

  // List of data types we request from Apple HealthKit / Google Health Connect
  final List<HealthDataType> _supportedTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BODY_MASS_INDEX,
  ];

  Future<bool> requestPermissions() async {
    try {
      // Check if Health data is available on device
      final bool isAvailable =
          await Health().hasPermissions(_supportedTypes) ?? false;
      if (isAvailable) return true;

      // Request authorization
      final bool authorized = await Health().requestAuthorization(
        _supportedTypes,
      );
      return authorized;
    } catch (e) {
      _log('Error requesting health permissions: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      return await Health().hasPermissions(_supportedTypes) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<List<HealthDataPoint>> fetchVitals(
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final bool hasAccess = await hasPermissions();
      if (!hasAccess) {
        final bool authorized = await requestPermissions();
        if (!authorized) return [];
      }

      // Fetch points from SDK
      final List<HealthDataPoint> points = await Health().getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: _supportedTypes,
      );

      // Clean/filter duplicates
      return Health().removeDuplicates(points);
    } catch (e) {
      _log('Error fetching platform health data: $e');
      return [];
    }
  }

  void _log(String msg) {
    print('[HEALTH_PLATFORM_ADAPTER] $msg');
  }
}
