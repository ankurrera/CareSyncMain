import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'custom_biometric_service.dart';
import '../features/shared/services/ocr_service.dart';

/// Service for handling KYC (Know Your Customer) verification
class KYCService {
  KYCService._();
  static final KYCService instance = KYCService._();

  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  // ─────────────────────────────────────────────────────────────────────────
  // KYC DOCUMENT UPLOAD
  // ─────────────────────────────────────────────────────────────────────────

  /// Pick an image from gallery for KYC documents
  Future<XFile?> pickImage() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      throw KYCException('Failed to pick image: $e');
    }
  }

  /// Take a photo with camera for KYC documents
  Future<XFile?> takePhoto() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      throw KYCException('Failed to take photo: $e');
    }
  }

  /// Upload KYC document to Supabase storage
  /// Returns the public URL of the uploaded file
  Future<String> uploadDocument({
    required File file,
    required String documentType, // 'id_document', 'selfie', 'additional'
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw KYCException('User not authenticated');
      }

      // Create unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last;
      final fileName = '$userId/$documentType-$timestamp.$extension';

      // Upload to Supabase storage
      await _supabase.storage.from('kyc-documents').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Generate a signed URL (1 hour) since kyc-documents is a private bucket.
      // getPublicUrl would return a URL that returns 400/403 for private buckets.
      final signedUrl = await _supabase.storage
          .from('kyc-documents')
          .createSignedUrl(fileName, 3600);

      return signedUrl;
    } on StorageException catch (e) {
      throw KYCException('Failed to upload document: ${e.message}');
    } catch (e) {
      throw KYCException('Failed to upload document: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KYC VERIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Submit KYC verification data
  /// Submit KYC verification data with automated OCR and Biometric verification gates.
  Future<void> submitKYC({
    required String fullName,
    required DateTime dateOfBirth,
    required String idDocumentUrl,
    required String selfieUrl,
    File? idDocumentFile,
    File? selfieFile,
    List<String>? additionalDocuments,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw KYCException('User not authenticated');
      }

      // --- OPTION A: AUTOMATED OCR VERIFICATION GATE ---
      if (idDocumentFile != null) {
        debugPrint('[KYC-GATE] Step 1: Performing OCR on Government ID document...');
        final ocrText = await OcrService().extractPlainText(idDocumentFile);
        debugPrint('[KYC-GATE] Extracted text from ID:\n$ocrText');

        // Fuzzy match Name: Check if at least one name part (length > 2) is present in the document
        final fullNameLower = fullName.toLowerCase();
        final nameParts = fullNameLower.split(RegExp(r'\s+')).where((part) => part.length > 2).toList();
        
        bool nameMatches = false;
        for (var part in nameParts) {
          if (ocrText.toLowerCase().contains(part)) {
            nameMatches = true;
            break;
          }
        }

        // Fuzzy match Birth Year: check if the document contains the year of birth
        final birthYear = dateOfBirth.year.toString();
        final dobMatches = ocrText.contains(birthYear);

        if (!nameMatches || !dobMatches) {
          debugPrint('[KYC-GATE] OCR mismatch: nameMatches=$nameMatches, dobMatches=$dobMatches');
          
          // Persist the attempt in Supabase as rejected
          await _supabase.from('kyc_verifications').upsert({
            'user_id': userId,
            'full_name': fullName,
            'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
            'id_document_url': idDocumentUrl,
            'selfie_url': selfieUrl,
            'additional_documents': additionalDocuments,
            'kyc_status': 'rejected',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
          
          throw KYCException(
            'Government ID Verification Failed: The name or birth year on the ID document does not match the entered profile details. Please make sure the photo is clear and matches the input.'
          );
        }
        debugPrint('[KYC-GATE] OCR Validation passed successfully.');
      }

      // --- OPTION A: BIOMETRIC 1:1 FACE MATCHING GATE ---
      if (idDocumentUrl.isNotEmpty && selfieUrl.isNotEmpty) {
        debugPrint('[KYC-GATE] Step 2: Executing 1:1 Biometric Face Match between Selfie and Government ID...');
        bool faceMatches = false;
        try {
          faceMatches = await CustomBiometricService.instance.verifyIDFace(
            selfieUrl: selfieUrl,
            idDocumentUrl: idDocumentUrl,
          );
        } catch (faceErr) {
          debugPrint('[KYC-GATE] Biometric check threw error: $faceErr');
          
          // Persist the failure
          await _supabase.from('kyc_verifications').upsert({
            'user_id': userId,
            'full_name': fullName,
            'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
            'id_document_url': idDocumentUrl,
            'selfie_url': selfieUrl,
            'additional_documents': additionalDocuments,
            'kyc_status': 'rejected',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
          
          throw KYCException('Facial Biometric Matching Failed: $faceErr');
        }

        if (!faceMatches) {
          debugPrint('[KYC-GATE] Face similarity check failed (mismatch).');
          
          await _supabase.from('kyc_verifications').upsert({
            'user_id': userId,
            'full_name': fullName,
            'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
            'id_document_url': idDocumentUrl,
            'selfie_url': selfieUrl,
            'additional_documents': additionalDocuments,
            'kyc_status': 'rejected',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');

          throw KYCException(
            'Facial Verification Failed: The face visible on the Government ID card does not match the live captured selfie. Please check lighting and verify the ID belongs to you.'
          );
        }
        debugPrint('[KYC-GATE] Biometric Face Matching passed successfully.');
      }

      // If all gates passed, verify the KYC status directly!
      final data = {
        'user_id': userId,
        'full_name': fullName,
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
        'id_document_url': idDocumentUrl,
        'selfie_url': selfieUrl,
        'additional_documents': additionalDocuments,
        'kyc_status': 'verified',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('kyc_verifications').upsert(data, onConflict: 'user_id');

      // Ensure the patient record exists in the 'patients' table
      try {
        final patientCheck = await _supabase
            .from('patients')
            .select('id')
            .eq('user_id', userId)
            .maybeSingle();

        if (patientCheck == null) {
          await _supabase.from('patients').insert({'user_id': userId});
        }
      } catch (dbErr) {
        debugPrint('[KYC] Error ensuring patient record exists: $dbErr');
      }

      // Enroll the patient's face with Custom Biometric API using their selfie
      try {
        await CustomBiometricService.instance.enrollPatient(
          userId: userId,
          selfieUrl: selfieUrl,
        );
      } catch (faceError) {
        debugPrint('[KYC] Biometric Face Enrollment failed (non-blocking): $faceError');
      }
    } on PostgrestException catch (e) {
      throw KYCException('Failed to submit KYC: ${e.message}');
    } on KYCException {
      rethrow;
    } catch (e) {
      throw KYCException('Failed to submit KYC: $e');
    }
  }

  /// Get KYC verification status for current user
  Future<KYCVerification?> getKYCStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('kyc_verifications')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

      return KYCVerification.fromJson(response);
    } on PostgrestException catch (e) {
      throw KYCException('Failed to get KYC status: ${e.message}');
    } catch (e) {
      throw KYCException('Failed to get KYC status: $e');
    }
  }

  /// Check if user has verified KYC
  /// ROBUST implementation per security requirements
  Future<bool> isKYCVerified([String? userId]) async {
    try {
      final targetUserId = userId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) return false;

      final res = await _supabase
          .from('kyc_verifications')
          .select('kyc_status')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return false;

      return res['kyc_status']?.toString().toLowerCase() == 'verified';
    } catch (e) {
      debugPrint('[KYC] Error checking KYC status: $e');
      return false;
    }
  }

  /// Check if user has pending KYC
  Future<bool> hasKYCPending() async {
    final kyc = await getKYCStatus();
    return kyc?.status == KYCStatus.pending;
  }

  /// Update KYC document URLs (for resubmission)
  Future<void> updateKYCDocuments({
    String? idDocumentUrl,
    String? selfieUrl,
    List<String>? additionalDocuments,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw KYCException('User not authenticated');
      }

      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (idDocumentUrl != null) data['id_document_url'] = idDocumentUrl;
      if (selfieUrl != null) data['selfie_url'] = selfieUrl;
      if (additionalDocuments != null) {
        data['additional_documents'] = additionalDocuments;
      }

      await _supabase
          .from('kyc_verifications')
          .update(data)
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw KYCException('Failed to update KYC documents: ${e.message}');
    } catch (e) {
      throw KYCException('Failed to update KYC documents: $e');
    }
  }

  /// Enroll a specific pose of the user's face to Custom Biometric API
  Future<void> enrollFacePose({
    required String userId,
    required String selfieUrl,
    required String poseLabel,
  }) async {
    try {
      await CustomBiometricService.instance.enrollPatient(
        userId: userId,
        selfieUrl: selfieUrl,
        poseLabel: poseLabel,
      );
    } catch (e) {
      debugPrint('[KYC] Failed to enroll face pose $poseLabel: $e');
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────

enum KYCStatus {
  pending,
  verified,
  rejected;

  static KYCStatus fromString(String status) {
    return KYCStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => KYCStatus.pending,
    );
  }
}

class KYCVerification {
  final String id;
  final String userId;
  final String fullName;
  final DateTime dateOfBirth;
  final String? idDocumentUrl;
  final String? selfieUrl;
  final List<String>? additionalDocuments;
  final KYCStatus status;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  KYCVerification({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.dateOfBirth,
    this.idDocumentUrl,
    this.selfieUrl,
    this.additionalDocuments,
    required this.status,
    this.rejectionReason,
    this.verifiedAt,
    this.verifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KYCVerification.fromJson(Map<String, dynamic> json) {
    return KYCVerification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      idDocumentUrl: json['id_document_url'] as String?,
      selfieUrl: json['selfie_url'] as String?,
      additionalDocuments: json['additional_documents'] != null
          ? List<String>.from(json['additional_documents'] as List)
          : null,
      status: KYCStatus.fromString(json['kyc_status'] as String),
      rejectionReason: json['rejection_reason'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      verifiedBy: json['verified_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
      'id_document_url': idDocumentUrl,
      'selfie_url': selfieUrl,
      'additional_documents': additionalDocuments,
      'kyc_status': status.name,
      'rejection_reason': rejectionReason,
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by': verifiedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Custom exception for KYC errors
class KYCException implements Exception {
  final String message;
  KYCException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when KYC verification is required
class KYCRequiredException extends KYCException {
  KYCRequiredException([String? message]) 
    : super(message ?? 'KYC verification required to access this feature');
}
