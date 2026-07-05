import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/env_config.dart';

/// Service class for interacting with the self-hosted ArcFace Biometric API.
class CustomBiometricService {
  CustomBiometricService._();
  static final CustomBiometricService instance = CustomBiometricService._();

  final _supabase = Supabase.instance.client;

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final token = EnvConfig.hfToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Enroll a patient's face by sending their user ID, selfie URL, and pose label
  /// to the self-hosted custom Biometric API.
  Future<void> enrollPatient({
    required String userId,
    required String selfieUrl,
    String poseLabel = 'neutral',
  }) async {
    try {
      debugPrint('[BIOMETRIC-API] Initiating face enrollment for user: $userId (pose: $poseLabel)');
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/enroll');
      
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'selfieUrl': selfieUrl,
          'poseLabel': poseLabel,
        }),
      );

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final errorMsg = errorData['detail'] ?? errorData['error'] ?? 'Enrollment failed with status ${response.statusCode}';
        throw Exception(errorMsg);
      }

      debugPrint('[BIOMETRIC-API] Face enrollment completed successfully.');
    } catch (e) {
      debugPrint('[BIOMETRIC-API] Error enrolling patient: $e');
      throw Exception('Failed to enroll facial biometrics: $e');
    }
  }

  /// Uploads a captured photo to the temporary 'emergency-scans' bucket,
  /// calls the custom Biometric API to run face detection and identification,
  /// and deletes the temporary file from storage afterward.
  /// 
  /// Returns a map containing:
  /// - `patient_id` (String)
  /// - `qr_code_id` (String)
  /// - `full_name` (String)
  /// - `similarity` (double)
  Future<Map<String, dynamic>?> identifyPatient(File faceImage) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = faceImage.path.split('.').last;
    final fileName = 'scans/$timestamp.$extension';

    try {
      debugPrint('[BIOMETRIC-API] Uploading temporary scan file to storage...');
      
      // 1. Upload scan to the private/temporary storage bucket
      await _supabase.storage.from('emergency-scans').upload(
            fileName,
            faceImage,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '0',
              upsert: true,
            ),
          );

      debugPrint('[BIOMETRIC-API] Scan file uploaded. Triggering identification API...');

      // 2. Call custom Biometric API to run detection and identification
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/identify');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'scanPath': fileName,
        }),
      );

      // Clean up the temporary scan file from storage asynchronously
      _supabase.storage.from('emergency-scans').remove([fileName]).then((_) {}).catchError((e) {
        debugPrint('[BIOMETRIC-API] Non-blocking warning: Failed to clean up temp scan file: $e');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          debugPrint('[BIOMETRIC-API] Patient identified: ${data['full_name']} (Similarity: ${data['similarity']})');
          return data;
        }
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final errorMsg = errorData['detail'] ?? errorData['error'] ?? 'Identification failed with status ${response.statusCode}';
        throw Exception(errorMsg);
      }

      return null;
    } catch (e) {
      // Clean up temp file in case of exception too
      _supabase.storage.from('emergency-scans').remove([fileName]).then((_) {}).catchError((_) {});
      
      debugPrint('[BIOMETRIC-API] Error during face identification: $e');
      rethrow;
    }
  }

  /// Verify 1:1 match of a selfie against the face on an ID document
  /// using the self-hosted custom Biometric API.
  Future<bool> verifyIDFace({
    required String selfieUrl,
    required String idDocumentUrl,
  }) async {
    try {
      debugPrint('[BIOMETRIC-API] Verifying face from selfie against ID document.');
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/verify_id');
      
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'selfieUrl': selfieUrl,
          'idDocumentUrl': idDocumentUrl,
        }),
      );

      if (response.statusCode != 200) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final errorMsg = errorData['detail'] ?? errorData['error'] ?? 'ID face matching failed with status ${response.statusCode}';
        throw Exception(errorMsg);
      }

      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['success'] == true) {
        final isVerified = data['verified'] == true;
        final similarity = data['similarity'] ?? 0.0;
        debugPrint('[BIOMETRIC-API] ID Verification: matches=$isVerified (similarity=${similarity.toStringAsFixed(2)})');
        return isVerified;
      }
      return false;
    } catch (e) {
      debugPrint('[BIOMETRIC-API] Error verifying ID face: $e');
      throw Exception('Failed to match selfie against ID photo: $e');
    }
  }
}
