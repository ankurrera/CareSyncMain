import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service class for interacting with the Azure Face API via Supabase Edge Functions.
class AzureFaceService {
  AzureFaceService._();
  static final AzureFaceService instance = AzureFaceService._();

  final _supabase = Supabase.instance.client;

  /// Enroll a patient's face by sending their user ID and their uploaded selfie URL
  /// to the Azure Face API via the Supabase Edge Function.
  Future<void> enrollPatient({
    required String userId,
    required String selfieUrl,
  }) async {
    try {
      debugPrint('[AZURE-FACE] Initiating face enrollment for user: $userId');
      final response = await _supabase.functions.invoke(
        'azure-face',
        body: {
          'action': 'enroll',
          'userId': userId,
          'selfieUrl': selfieUrl,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? 'Enrollment failed with status ${response.status}';
        throw Exception(errorMsg);
      }

      debugPrint('[AZURE-FACE] Face enrollment completed successfully.');
    } catch (e) {
      debugPrint('[AZURE-FACE] Error enrolling patient: $e');
      throw Exception('Failed to enroll facial biometrics: $e');
    }
  }

  /// Uploads a captured photo to the temporary 'emergency-scans' bucket,
  /// calls the Edge Function to run Azure Face detection and identification,
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
      debugPrint('[AZURE-FACE] Uploading temporary scan file to storage...');
      
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

      debugPrint('[AZURE-FACE] Scan file uploaded. Triggering identification Edge Function...');

      // 2. Invoke the Edge Function to detect and identify
      final response = await _supabase.functions.invoke(
        'azure-face',
        body: {
          'action': 'identify',
          'scanPath': fileName,
        },
      );

      // Clean up the temporary scan file from storage asynchronously
      _supabase.storage.from('emergency-scans').remove([fileName]).then((_) {}).catchError((e) {
        debugPrint('[AZURE-FACE] Non-blocking warning: Failed to clean up temp scan file: $e');
      });

      if (response.status == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['success'] == true) {
          debugPrint('[AZURE-FACE] Patient identified: ${data['full_name']} (Similarity: ${data['similarity']})');
          return data;
        }
      } else {
        final errorMsg = response.data['error'] ?? 'Identification failed with status ${response.status}';
        throw Exception(errorMsg);
      }

      return null;
    } on FunctionException catch (fe) {
      // Clean up temp file in case of exception too
      _supabase.storage.from('emergency-scans').remove([fileName]).then((_) {}).catchError((_) {});
      
      debugPrint('[AZURE-FACE] Supabase Function Exception: ${fe.toString()}');
      throw Exception(fe.toString());
    } catch (e) {
      // Clean up temp file in case of exception too
      _supabase.storage.from('emergency-scans').remove([fileName]).then((_) {}).catchError((_) {});
      
      debugPrint('[AZURE-FACE] General error during face identification: $e');
      rethrow;
    }
  }
}
