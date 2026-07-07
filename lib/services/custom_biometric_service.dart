import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/config/env_config.dart';

/// Typed enumeration representing the outcomes of biometric operations
enum BiometricResultStatus {
  success,
  noMatch,
  offline,
  timeout,
  serverError,
  alreadyEnrolled,
  qualityRejected,
  cancelled
}

/// Scan state machine representing the lifecycle of face scanning
enum BiometricScanState {
  idle,
  openingCamera,
  capturing,
  uploading,
  detectingFace,
  generatingEmbedding,
  searchingDatabase,
  verifyingMatch,
  completed,
  failed
}

/// Standardized error codes matching the backend microservice
enum BiometricErrorCode {
  none,
  noFaceDetected,
  noMatchFound,
  multipleFaces,
  faceTooSmall,
  faceTooFar,
  faceOccluded,
  lowLight,
  overExposed,
  imageBlur,
  invalidImage,
  emptyImage,
  lowConfidence,
  cameraError,
  networkError,
  timeout,
  serverError,
  rateLimited,
  livenessFailed,
  alreadyEnrolled,
  unauthorized,
  cameraPermission,
  unknown
}

/// Parse string error code from backend into BiometricErrorCode enum
BiometricErrorCode parseErrorCode(String? code) {
  if (code == null) return BiometricErrorCode.none;
  switch (code) {
    case 'NO_FACE_DETECTED': return BiometricErrorCode.noFaceDetected;
    case 'NO_MATCH_FOUND': return BiometricErrorCode.noMatchFound;
    case 'MULTIPLE_FACES': return BiometricErrorCode.multipleFaces;
    case 'FACE_TOO_SMALL': return BiometricErrorCode.faceTooSmall;
    case 'FACE_TOO_FAR': return BiometricErrorCode.faceTooFar;
    case 'FACE_OCCLUDED': return BiometricErrorCode.faceOccluded;
    case 'LOW_LIGHT': return BiometricErrorCode.lowLight;
    case 'OVER_EXPOSED': return BiometricErrorCode.overExposed;
    case 'IMAGE_BLUR': return BiometricErrorCode.imageBlur;
    case 'INVALID_IMAGE': return BiometricErrorCode.invalidImage;
    case 'EMPTY_IMAGE': return BiometricErrorCode.emptyImage;
    case 'LOW_CONFIDENCE': return BiometricErrorCode.lowConfidence;
    case 'CAMERA_ERROR': return BiometricErrorCode.cameraError;
    case 'NETWORK_ERROR': return BiometricErrorCode.networkError;
    case 'TIMEOUT': return BiometricErrorCode.timeout;
    case 'SERVER_ERROR': return BiometricErrorCode.serverError;
    case 'RATE_LIMITED': return BiometricErrorCode.rateLimited;
    case 'LIVENESS_FAILED': return BiometricErrorCode.livenessFailed;
    case 'ALREADY_ENROLLED': return BiometricErrorCode.alreadyEnrolled;
    case 'UNAUTHORIZED': return BiometricErrorCode.unauthorized;
    case 'CAMERA_PERMISSION': return BiometricErrorCode.cameraPermission;
    default: return BiometricErrorCode.unknown;
  }
}

/// Token used to cancel active biometric requests
class BiometricCancelToken {
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
    debugPrint('[BIOMETRIC] Request cancellation triggered by client.');
  }

  bool get isCancelled => _isCancelled;
}

/// Model for identification details
class BiometricIdentifyResult {
  final BiometricResultStatus status;
  final BiometricErrorCode errorCode;
  final String? patientId;
  final String? qrCodeId;
  final String? fullName;
  final double? similarity;
  final double? confidence;
  final String? poseMatched;
  final String? errorMessage;
  final Map<String, dynamic>? qualityMetrics;
  final Map<String, dynamic>? consensus;
  final double? latency;
  final String? requestId;

  BiometricIdentifyResult({
    required this.status,
    this.errorCode = BiometricErrorCode.none,
    this.patientId,
    this.qrCodeId,
    this.fullName,
    this.similarity,
    this.confidence,
    this.poseMatched,
    this.errorMessage,
    this.qualityMetrics,
    this.consensus,
    this.latency,
    this.requestId,
  });
}

/// Model for face enrollment outcomes
class BiometricEnrollResult {
  final BiometricResultStatus status;
  final BiometricErrorCode errorCode;
  final String? patientId;
  final String? poseEnrolled;
  final String? errorMessage;
  final Map<String, dynamic>? qualityMetrics;
  final double? latency;
  final String? requestId;

  BiometricEnrollResult({
    required this.status,
    this.errorCode = BiometricErrorCode.none,
    this.patientId,
    this.poseEnrolled,
    this.errorMessage,
    this.qualityMetrics,
    this.latency,
    this.requestId,
  });
}

/// Model for 1:1 face comparison outcomes
class BiometricVerifyResult {
  final BiometricResultStatus status;
  final BiometricErrorCode errorCode;
  final bool verified;
  final double? similarity;
  final String? errorMessage;
  final double? latency;
  final String? requestId;

  BiometricVerifyResult({
    required this.status,
    this.errorCode = BiometricErrorCode.none,
    required this.verified,
    this.similarity,
    this.errorMessage,
    this.latency,
    this.requestId,
  });
}

/// Service class for interacting with the self-hosted ArcFace Biometric API.
class CustomBiometricService {
  CustomBiometricService._();
  static final CustomBiometricService instance = CustomBiometricService._();

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final token = EnvConfig.hfToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    // Attach tracking correlation request headers
    headers['X-Request-Id'] = const Uuid().v4();

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        headers['X-Actor-Id'] = currentUser.id;
      }
    } catch (e) {
      debugPrint('[BIOMETRIC] Error adding X-Actor-Id header: $e');
    }
    return headers;
  }

  // Helper method to post requests with transient failure retries and cancellation check
  Future<http.Response> _postWithRetry(
    Uri url, {
    required Map<String, String> headers,
    required Object body,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 15),
    BiometricCancelToken? cancelToken,
  }) async {
    int attempts = 0;
    final String idempotencyKey = const Uuid().v4();
    final Map<String, String> requestHeaders = Map<String, String>.from(headers);
    requestHeaders['X-Idempotency-Key'] = idempotencyKey;

    while (true) {
      attempts++;
      if (cancelToken?.isCancelled == true) {
        throw Exception('Request cancelled.');
      }
      try {
        final response = await http.post(
          url,
          headers: requestHeaders,
          body: body,
        ).timeout(timeout);
        return response;
      } catch (e) {
        final isTransient = e is SocketException || e is TimeoutException;
        if (isTransient && attempts < maxRetries) {
          final delayMs = attempts * 1000;
          debugPrint('[BIOMETRIC] Transient error on attempt $attempts: $e. Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        rethrow;
      }
    }
  }

  // Helper method to post multipart request with transient failure retries
  Future<http.Response> _sendMultipartWithRetry(
    Uri url,
    File faceImage, {
    required Map<String, String> headers,
    Map<String, String>? fields,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 20),
    BiometricCancelToken? cancelToken,
  }) async {
    int attempts = 0;
    final String idempotencyKey = const Uuid().v4();
    final Map<String, String> requestHeaders = Map<String, String>.from(headers);
    requestHeaders['X-Idempotency-Key'] = idempotencyKey;

    while (true) {
      attempts++;
      if (cancelToken?.isCancelled == true) {
        throw Exception('Request cancelled.');
      }
      try {
        final request = http.MultipartRequest('POST', url);
        requestHeaders.forEach((key, value) {
          request.headers[key] = value;
        });
        if (fields != null) {
          request.fields.addAll(fields);
        }
        
        final stream = http.ByteStream(faceImage.openRead());
        final length = await faceImage.length();
        final multipartFile = http.MultipartFile(
          'file',
          stream,
          length,
          filename: faceImage.path.split('/').last,
        );
        request.files.add(multipartFile);
        
        final streamedResponse = await request.send().timeout(timeout);
        final response = await http.Response.fromStream(streamedResponse);
        return response;
      } catch (e) {
        final isTransient = e is SocketException || e is TimeoutException;
        if (isTransient && attempts < maxRetries) {
          final delayMs = attempts * 1000;
          debugPrint('[BIOMETRIC] Transient multipart error on attempt $attempts: $e. Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        rethrow;
      }
    }
  }

  // ============================================================================
  // BACKWARD COMPATIBLE API FAÇADES
  // ============================================================================

  /// Legacy Enroll Patient wrapper
  Future<void> enrollPatient({
    required String userId,
    required String selfieUrl,
    String poseLabel = 'neutral',
  }) async {
    final result = await enrollPatientDetailed(
      userId: userId,
      selfieUrl: selfieUrl,
      poseLabel: poseLabel,
    );
    if (result.status != BiometricResultStatus.success) {
      throw Exception(result.errorMessage ?? 'Enrollment failed.');
    }
  }

  /// Legacy Identify Patient wrapper
  Future<Map<String, dynamic>?> identifyPatient(File faceImage) async {
    final result = await identifyPatientDetailed(faceImage);
    if (result.status == BiometricResultStatus.success) {
      return {
        'patient_id': result.patientId,
        'qr_code_id': result.qrCodeId,
        'full_name': result.fullName,
        'similarity': result.similarity,
        'confidence': result.confidence,
        'success': true
      };
    }
    return null;
  }

  /// Legacy ID Face verification wrapper
  Future<bool> verifyIDFace({
    required String selfieUrl,
    required String idDocumentUrl,
  }) async {
    final result = await verifyIDFaceDetailed(
      selfieUrl: selfieUrl,
      idDocumentUrl: idDocumentUrl,
    );
    return result.verified;
  }

  Map<String, dynamic> _safeParseJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {};
    }
  }

  // ============================================================================
  // TYPED ENTERPRISE BIOMETRIC API METHODS
  // ============================================================================

  /// Enroll a patient's face by sending their user ID, selfie URL, and pose label
  Future<BiometricEnrollResult> enrollPatientDetailed({
    required String userId,
    required String selfieUrl,
    String poseLabel = 'neutral',
    String? enrollmentSessionId,
    String? deviceInfo,
    String? camera,
    String? captureTime,
    BiometricCancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();
    try {
      debugPrint('[BIOMETRIC-API] Initiating face enrollment for user: $userId (pose: $poseLabel)');
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/enroll');
      
      final response = await _postWithRetry(
        url,
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'selfieUrl': selfieUrl,
          'poseLabel': poseLabel,
          'enrollment_session_id': enrollmentSessionId,
          'device_info': deviceInfo,
          'camera': camera,
          'capture_time': captureTime,
        }),
        cancelToken: cancelToken,
      );

      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final data = _safeParseJson(response.body);
      final String? backendErrorCode = data['error_code'];
      final String? backendMessage = data['message'] ?? data['detail'];
      final String? requestId = data['request_id'];
      final errCode = parseErrorCode(backendErrorCode);

      if (response.statusCode == 200) {
        debugPrint('[BIOMETRIC-API] Face enrollment completed successfully.');
        return BiometricEnrollResult(
          status: BiometricResultStatus.success,
          errorCode: errCode,
          patientId: data['patient_id'],
          poseEnrolled: data['pose_enrolled'],
          qualityMetrics: data['quality_metrics'],
          latency: latency,
          requestId: requestId,
        );
      } else if (response.statusCode == 409) {
        return BiometricEnrollResult(
          status: BiometricResultStatus.alreadyEnrolled,
          errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.alreadyEnrolled : errCode,
          errorMessage: backendMessage ?? 'Biometrics already registered under another account.',
          latency: latency,
          requestId: requestId,
        );
      } else if (response.statusCode == 400) {
        return BiometricEnrollResult(
          status: BiometricResultStatus.qualityRejected,
          errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.lowLight : errCode,
          errorMessage: backendMessage ?? 'Enrollment rejected due to low biometric quality checks.',
          latency: latency,
          requestId: requestId,
        );
      } else {
        return BiometricEnrollResult(
          status: BiometricResultStatus.serverError,
          errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.serverError : errCode,
          errorMessage: backendMessage ?? 'Server error occurred during enrollment.',
          latency: latency,
          requestId: requestId,
        );
      }
    } on TimeoutException {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      return BiometricEnrollResult(
        status: BiometricResultStatus.timeout,
        errorCode: BiometricErrorCode.timeout,
        errorMessage: 'Connection timeout.',
        latency: latency,
      );
    } on SocketException {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      return BiometricEnrollResult(
        status: BiometricResultStatus.offline,
        errorCode: BiometricErrorCode.networkError,
        errorMessage: 'Network offline.',
        latency: latency,
      );
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      if (e.toString().contains('cancelled')) {
        return BiometricEnrollResult(
          status: BiometricResultStatus.cancelled,
          errorCode: BiometricErrorCode.none,
          errorMessage: 'Operation cancelled.',
          latency: latency,
        );
      }
      return BiometricEnrollResult(
        status: BiometricResultStatus.serverError,
        errorCode: BiometricErrorCode.serverError,
        errorMessage: e.toString(),
        latency: latency,
      );
    }
  }

  /// Analyze a preview frame image for real-time guided scan feedback
  Future<Map<String, dynamic>> analyzeFrame(File frameImage, {String? targetPose, BiometricCancelToken? cancelToken}) async {
    try {
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/analyze_frame');
      final response = await _sendMultipartWithRetry(
        url,
        frameImage,
        headers: _headers,
        fields: targetPose != null ? {'target_pose': targetPose} : null,
        cancelToken: cancelToken,
        maxRetries: 1,
        timeout: const Duration(seconds: 4),
      );
      if (response.statusCode == 200) {
        return _safeParseJson(response.body);
      }
      return {'success': false, 'message': 'HTTP error ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Identifies a patient from a direct local file image scan
  Future<BiometricIdentifyResult> identifyPatientDetailed(
    File faceImage, {
    BiometricCancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();
    try {
      debugPrint('[BIOMETRIC-API] Streaming face scan bytes directly to microservice...');
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/identify');
      
      final response = await _sendMultipartWithRetry(
        url,
        faceImage,
        headers: _headers,
        cancelToken: cancelToken,
      );

      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final data = _safeParseJson(response.body);
      final String? backendErrorCode = data['error_code'];
      final String? backendMessage = data['message'] ?? data['detail'];
      final String? requestId = data['request_id'];
      final errCode = parseErrorCode(backendErrorCode);

      if (response.statusCode == 200) {
        if (data['success'] == true) {
          debugPrint('[BIOMETRIC-API] Patient identified: ${data['full_name']}');
          
          // Phase 10 response validation
          final patientId = data['patient_id'];
          final fullName = data['full_name'];
          final qrCodeId = data['qr_code_id'];
          final similarity = data['similarity'];
          final confidence = data['confidence'];

          if (patientId == null || fullName == null || qrCodeId == null || similarity == null || confidence == null) {
            return BiometricIdentifyResult(
              status: BiometricResultStatus.serverError,
              errorCode: BiometricErrorCode.serverError,
              errorMessage: 'Malformed biometric API response: missing required fields.',
              latency: latency,
              requestId: requestId,
            );
          }

          return BiometricIdentifyResult(
            status: BiometricResultStatus.success,
            errorCode: BiometricErrorCode.none,
            patientId: patientId.toString(),
            qrCodeId: qrCodeId.toString(),
            fullName: fullName.toString(),
            similarity: (similarity as num).toDouble(),
            confidence: (confidence as num).toDouble(),
            poseMatched: data['pose_matched']?.toString(),
            qualityMetrics: data['quality_metrics'],
            consensus: data['consensus'],
            latency: latency,
            requestId: requestId,
          );
        }
      } else if (response.statusCode == 404) {
        debugPrint('[BIOMETRIC-API] No matching profile found (404)');
        return BiometricIdentifyResult(
          status: BiometricResultStatus.noMatch,
          errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.noMatchFound : errCode,
          errorMessage: backendMessage ?? 'No match found.',
          latency: latency,
          requestId: requestId,
        );
      } else if (response.statusCode == 400) {
        return BiometricIdentifyResult(
          status: BiometricResultStatus.qualityRejected,
          errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.lowLight : errCode,
          errorMessage: backendMessage ?? 'Scan rejected due to face quality check failures.',
          latency: latency,
          requestId: requestId,
        );
      }
      
      return BiometricIdentifyResult(
        status: BiometricResultStatus.serverError,
        errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.serverError : errCode,
        errorMessage: backendMessage ?? 'Server error occurred during identification.',
        latency: latency,
        requestId: requestId,
      );
    } on TimeoutException {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      return BiometricIdentifyResult(
        status: BiometricResultStatus.timeout,
        errorCode: BiometricErrorCode.timeout,
        errorMessage: 'Connection timed out.',
        latency: latency,
      );
    } on SocketException {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      return BiometricIdentifyResult(
        status: BiometricResultStatus.offline,
        errorCode: BiometricErrorCode.networkError,
        errorMessage: 'No network connection.',
        latency: latency,
      );
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      if (e.toString().contains('cancelled')) {
        return BiometricIdentifyResult(
          status: BiometricResultStatus.cancelled,
          errorCode: BiometricErrorCode.none,
          errorMessage: 'Operation cancelled.',
          latency: latency,
        );
      }
      return BiometricIdentifyResult(
        status: BiometricResultStatus.serverError,
        errorCode: BiometricErrorCode.serverError,
        errorMessage: e.toString(),
        latency: latency,
      );
    }
  }

  /// Verify 1:1 match of a selfie against the face on an ID document
  Future<BiometricVerifyResult> verifyIDFaceDetailed({
    required String selfieUrl,
    required String idDocumentUrl,
    BiometricCancelToken? cancelToken,
  }) async {
    final startTime = DateTime.now();
    try {
      debugPrint('[BIOMETRIC-API] Verifying face from selfie against ID document.');
      final url = Uri.parse('${EnvConfig.biometricApiUrl}/verify_id');
      
      final response = await _postWithRetry(
        url,
        headers: _headers,
        body: jsonEncode({
          'selfieUrl': selfieUrl,
          'idDocumentUrl': idDocumentUrl,
        }),
        cancelToken: cancelToken,
      );

      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      final data = _safeParseJson(response.body);
      final String? backendErrorCode = data['error_code'];
      final String? backendMessage = data['message'] ?? data['detail'];
      final String? requestId = data['request_id'];
      final errCode = parseErrorCode(backendErrorCode);

      if (response.statusCode == 200) {
        final isVerified = data['verified'] == true;
        final similarity = (data['similarity'] as num?)?.toDouble() ?? 0.0;
        debugPrint('[BIOMETRIC-API] ID Verification matches=$isVerified');
        return BiometricVerifyResult(
          status: BiometricResultStatus.success,
          errorCode: BiometricErrorCode.none,
          verified: isVerified,
          similarity: similarity,
          latency: latency,
          requestId: requestId,
        );
      } else if (response.statusCode == 400) {
        return BiometricVerifyResult(
          status: BiometricResultStatus.qualityRejected,
          errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.lowLight : errCode,
          verified: false,
          errorMessage: backendMessage ?? 'ID verification rejected due to face occlusion/detection errors.',
          latency: latency,
          requestId: requestId,
        );
      }
      
      return BiometricVerifyResult(
        status: BiometricResultStatus.serverError,
        errorCode: errCode == BiometricErrorCode.none ? BiometricErrorCode.serverError : errCode,
        verified: false,
        errorMessage: backendMessage ?? 'Server error occurred during ID comparison.',
        latency: latency,
        requestId: requestId,
      );
    } on TimeoutException {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      return BiometricVerifyResult(
        status: BiometricResultStatus.timeout,
        errorCode: BiometricErrorCode.timeout,
        verified: false,
        errorMessage: 'Connection timeout.',
        latency: latency,
      );
    } on SocketException {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      return BiometricVerifyResult(
        status: BiometricResultStatus.offline,
        errorCode: BiometricErrorCode.networkError,
        verified: false,
        errorMessage: 'Network offline.',
        latency: latency,
      );
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      if (e.toString().contains('cancelled')) {
        return BiometricVerifyResult(
          status: BiometricResultStatus.cancelled,
          errorCode: BiometricErrorCode.none,
          verified: false,
          errorMessage: 'Operation cancelled.',
          latency: latency,
        );
      }
      return BiometricVerifyResult(
        status: BiometricResultStatus.serverError,
        errorCode: BiometricErrorCode.serverError,
        verified: false,
        errorMessage: e.toString(),
        latency: latency,
      );
    }
  }

  /// Map a biometric result to a human-friendly error message based on Phase 3/8 requirements
  String mapStatusToErrorMessage(BiometricResultStatus status, String? rawError, {BiometricErrorCode errorCode = BiometricErrorCode.none}) {
    if (errorCode != BiometricErrorCode.none) {
      switch (errorCode) {
        case BiometricErrorCode.noFaceDetected:
          return 'No Face Found';
        case BiometricErrorCode.noMatchFound:
          return 'No Matching Patient Found';
        case BiometricErrorCode.imageBlur:
          return 'Image Too Blurry';
        case BiometricErrorCode.faceTooFar:
        case BiometricErrorCode.faceTooSmall:
          return 'Move Closer To Camera';
        case BiometricErrorCode.multipleFaces:
          return 'Multiple Faces Detected';
        case BiometricErrorCode.faceOccluded:
          return 'Face Cannot Be Verified';
        case BiometricErrorCode.lowLight:
          return 'Poor Lighting';
        case BiometricErrorCode.overExposed:
          return 'Lighting Too Bright';
        case BiometricErrorCode.emptyImage:
          return 'No Image Received';
        case BiometricErrorCode.invalidImage:
          return 'Invalid Image Format';
        case BiometricErrorCode.networkError:
          return 'Network Error';
        case BiometricErrorCode.timeout:
          return 'Request Timed Out';
        case BiometricErrorCode.serverError:
          return 'Server Error';
        case BiometricErrorCode.cameraPermission:
          return 'Camera Permission Required';
        case BiometricErrorCode.rateLimited:
          return 'Request Timed Out';
        default:
          break;
      }
    }

    if (status == BiometricResultStatus.timeout) {
      return 'Request Timed Out';
    }
    if (status == BiometricResultStatus.offline) {
      return 'Network Error';
    }
    if (status == BiometricResultStatus.noMatch) {
      return 'No Matching Patient Found';
    }
    if (status == BiometricResultStatus.qualityRejected || status == BiometricResultStatus.serverError) {
      final err = rawError?.toLowerCase() ?? '';
      if (err.contains('no face detected') || err.contains('face not detected')) {
        return 'No Face Found';
      }
      if (err.contains('multiple faces')) {
        return 'Multiple Faces Detected';
      }
      if (err.contains('too small') || err.contains('too far') || err.contains('move closer')) {
        return 'Move Closer To Camera';
      }
      if (err.contains('blurred') || err.contains('focus')) {
        return 'Image Too Blurry';
      }
      if (err.contains('occluded') || err.contains('mask') || err.contains('glasses') || err.contains('sunglasses')) {
        return 'Face Cannot Be Verified';
      }
      if (err.contains('dark') || err.contains('lighting too dark') || err.contains('poor lighting')) {
        return 'Poor Lighting';
      }
      if (err.contains('bright') || err.contains('lighting too bright') || err.contains('overexposed') || err.contains('over exposed')) {
        return 'Lighting Too Bright';
      }
      if (err.contains('empty')) {
        return 'No Image Received';
      }
      if (err.contains('not a valid image') || err.contains('corrupted')) {
        return 'Invalid Image Format';
      }
      if (status == BiometricResultStatus.serverError) {
        return 'Server Error';
      }
    }
    return rawError ?? 'Please Try Again';
  }
}
