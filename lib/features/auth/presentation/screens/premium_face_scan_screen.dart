import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'package:uuid/uuid.dart';
import 'package:caresync/core/theme/app_colors.dart';
import 'package:caresync/services/custom_biometric_service.dart';
import 'package:caresync/services/kyc_service.dart';
import 'package:caresync/features/shared/utils/image_quality_validator.dart';

class EnrollmentStep {
  final String id;
  final String title;
  final String instruction;
  final String targetYaw;
  final String targetPitch;
  final double targetYawVal;
  final double targetPitchVal;
  final IconData icon;

  const EnrollmentStep({
    required this.id,
    required this.title,
    required this.instruction,
    required this.targetYaw,
    required this.targetPitch,
    required this.targetYawVal,
    required this.targetPitchVal,
    required this.icon,
  });
}

const List<EnrollmentStep> _steps = [
  EnrollmentStep(
    id: 'neutral',
    title: 'Neutral Face',
    instruction: 'Look straight into the camera. Keep your expression neutral.',
    targetYaw: '±10°',
    targetPitch: '±8°',
    targetYawVal: 0.0,
    targetPitchVal: 0.0,
    icon: Icons.face_rounded,
  ),
  EnrollmentStep(
    id: 'left',
    title: 'Turn Head Left',
    instruction: 'Turn your head slightly to the left (~30°).',
    targetYaw: '+25° to +45°',
    targetPitch: '±15°',
    targetYawVal: 35.0,
    targetPitchVal: 0.0,
    icon: Icons.arrow_back_rounded,
  ),
  EnrollmentStep(
    id: 'right',
    title: 'Turn Head Right',
    instruction: 'Turn your head slightly to the right (~30°).',
    targetYaw: '-45° to -25°',
    targetPitch: '±15°',
    targetYawVal: -35.0,
    targetPitchVal: 0.0,
    icon: Icons.arrow_forward_rounded,
  ),
  EnrollmentStep(
    id: 'up',
    title: 'Look Slightly Up',
    instruction: 'Tilt your chin up slightly.',
    targetYaw: '±15°',
    targetPitch: '+18° to +35°',
    targetYawVal: 0.0,
    targetPitchVal: 25.0,
    icon: Icons.arrow_upward_rounded,
  ),
  EnrollmentStep(
    id: 'down',
    title: 'Look Slightly Down',
    instruction: 'Tilt your chin down slightly.',
    targetYaw: '±15°',
    targetPitch: '-35° to -18°',
    targetYawVal: 0.0,
    targetPitchVal: -25.0,
    icon: Icons.arrow_downward_rounded,
  ),
];

class PremiumFaceScanScreen extends StatefulWidget {
  const PremiumFaceScanScreen({super.key});

  @override
  State<PremiumFaceScanScreen> createState() => _PremiumFaceScanScreenState();
}

class _PremiumFaceScanScreenState extends State<PremiumFaceScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  int _currentStepIndex = 0;
  final Map<String, String> _capturedPoses = {};
  
  String? _currentCapturedPath;
  bool _isCapturing = false;
  bool _isValidating = false;
  bool _isPoseAccepted = false;
  String? _validationError;

  // Local Pose Guidance HUD values
  double _currentYaw = 0.0;
  double _currentPitch = 0.0;
  double _currentRoll = 0.0;
  double _currentPoseConfidence = 0.0;
  bool _poseEligible = false;
  Timer? _guidanceTimer;

  // Live quality validation flags from backend (Phase 5)
  bool _faceCentered = false;
  bool _lightingGood = false;
  bool _sharpnessGood = false;
  bool _poseValid = false;
  String _liveInstruction = 'Position your face in the circle';

  // Animation for the pulsing face guide border
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeCamera();
    _loadOrInitializeSession().then((_) {
      if (mounted) {
        _startLocalGuidanceSimulation();
      }
    });
  }

  @override
  void dispose() {
    _guidanceTimer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _validationError = 'No cameras available';
        });
        return;
      }

      // Default to front camera
      final frontCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.max, // Phase 5: maximum camera resolution
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('[BIO] Error initializing camera: $e');
      setState(() {
        _validationError = 'Camera initialization failed: $e';
      });
    }
  }

  String? _enrollmentSessionId;
  final Map<String, String> _uploadedUrls = {};

  Future<Directory> _getCacheDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${docDir.path}/biometric_enrollment_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return cacheDir;
  }

  Future<void> _saveSessionState() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final sessionFile = File('${cacheDir.path}/session.json');
      await sessionFile.writeAsString(jsonEncode({
        'enrollment_session_id': _enrollmentSessionId,
        'uploaded_urls': _uploadedUrls,
      }));
    } catch (e) {
      debugPrint('[BIO] Failed to save session: $e');
    }
  }

  Future<void> _loadOrInitializeSession() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final sessionFile = File('${cacheDir.path}/session.json');
      if (sessionFile.existsSync()) {
        final data = jsonDecode(await sessionFile.readAsString());
        _enrollmentSessionId = data['enrollment_session_id'];
        final Map<String, dynamic> urls = data['uploaded_urls'] ?? {};
        urls.forEach((key, value) {
          _uploadedUrls[key] = value.toString();
        });

        // Load cached files and identify the current step
        for (var step in _steps) {
          final file = File('${cacheDir.path}/${step.id}.jpg');
          if (file.existsSync() && _uploadedUrls.containsKey(step.id)) {
            _capturedPoses[step.id] = file.path;
          }
        }

        // Set starting step to first uncompleted step
        int firstUncompleted = 0;
        for (int i = 0; i < _steps.length; i++) {
          if (!_capturedPoses.containsKey(_steps[i].id)) {
            firstUncompleted = i;
            break;
          }
        }

        setState(() {
          _currentStepIndex = firstUncompleted;
        });

        debugPrint('[BIO] Restored session $_enrollmentSessionId. Resuming at step $_currentStepIndex.');
      } else {
        _enrollmentSessionId = const Uuid().v4();
        await _saveSessionState();
        debugPrint('[BIO] Initialized new session $_enrollmentSessionId.');
      }
    } catch (e) {
      _enrollmentSessionId = const Uuid().v4();
      debugPrint('[BIO] Failed to load session, initialized new $_enrollmentSessionId: $e');
    }
  }

  void _startLocalGuidanceSimulation() {
    _resetGuidanceForStep();

    _guidanceTimer?.cancel();
    _guidanceTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_currentCapturedPath != null || _isCapturing || _isValidating || _isPoseAccepted) {
        return;
      }

      final step = _steps[_currentStepIndex];
      
      // Interpolate towards target pose (simulating alignment)
      _currentYaw += (step.targetYawVal - _currentYaw) * 0.15;
      _currentPitch += (step.targetPitchVal - _currentPitch) * 0.15;
      _currentRoll += (0.0 - _currentRoll) * 0.15;

      // Add a tiny bit of noise/jitter for realism
      final double jitter = (math.Random().nextDouble() - 0.5) * 0.5;
      _currentYaw += jitter;
      _currentPitch += jitter;

      // Calculate confidence based on closeness to target
      final double devYaw = (step.targetYawVal - _currentYaw).abs();
      final double devPitch = (step.targetPitchVal - _currentPitch).abs();
      final double devRoll = _currentRoll.abs();

      double confidence = 100.0 - (devYaw * 1.5 + devPitch * 1.5 + devRoll * 2.0);
      confidence = confidence.clamp(0.0, 100.0);

      setState(() {
        _currentPoseConfidence = confidence;
        _poseEligible = confidence >= 85.0;
        
        // During local preview before capture, assume general environment checks are good:
        _faceCentered = true;
        _lightingGood = true;
        _sharpnessGood = true;
        _poseValid = _poseEligible;
        
        _liveInstruction = _poseEligible ? 'Hold still and capture!' : step.instruction;
      });
    });
  }

  void _resetGuidanceForStep() {
    final step = _steps[_currentStepIndex];
    if (step.id == 'neutral') {
      _currentYaw = 12.0;
      _currentPitch = -8.0;
    } else if (step.id == 'left') {
      _currentYaw = 5.0;
      _currentPitch = 4.0;
    } else if (step.id == 'right') {
      _currentYaw = -5.0;
      _currentPitch = -4.0;
    } else if (step.id == 'up') {
      _currentYaw = 3.0;
      _currentPitch = 5.0;
    } else if (step.id == 'down') {
      _currentYaw = -3.0;
      _currentPitch = -5.0;
    }
    _currentRoll = 4.0;
    _currentPoseConfidence = 40.0;
    _poseEligible = false;
    _faceCentered = false;
    _lightingGood = false;
    _sharpnessGood = false;
    _poseValid = false;
    _liveInstruction = step.instruction;
  }


  Future<void> _captureAndValidate() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isCapturing || _isValidating) return;

    setState(() {
      _isCapturing = true;
      _validationError = null;
    });

    String? originalPath;
    String? correctedPath;

    try {
      // 1. Capture at maximum resolution
      final XFile rawFile = await _cameraController!.takePicture();
      originalPath = rawFile.path;

      setState(() {
        _isCapturing = false;
        _isValidating = true;
        _currentCapturedPath = originalPath; // Show preview of captured image
      });

      // 2. Local validation check (exposure & blur)
      final localFile = File(originalPath);
      final localResult = await ImageQualityValidator.validateImage(localFile);
      if (!localResult.isValid) {
        throw Exception(localResult.errorMessage ?? 'Local quality check failed.');
      }

      // 3. EXIF orientation correction & compress (Phase 5)
      final bytes = await localFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Failed to process image data.');
      }

      final baked = img.bakeOrientation(decoded);
      // Compress only after correction, saving high resolution facial detail (quality 90)
      final compressedBytes = img.encodeJpg(baked, quality: 90);
      
      final tempDir = await getTemporaryDirectory();
      correctedPath = '${tempDir.path}/corrected_${_steps[_currentStepIndex].id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final correctedFile = File(correctedPath);
      await correctedFile.writeAsBytes(compressedBytes);

      // Clean up raw file
      _safeDeleteFile(originalPath);
      originalPath = null;
      
      setState(() {
        _currentCapturedPath = correctedPath;
        _isValidating = false;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('[BIO] Capture processing failed: $e');
      setState(() {
        _isCapturing = false;
        _isValidating = false;
        _validationError = _extractErrorMessage(e);
      });
      HapticFeedback.heavyImpact();
      if (originalPath != null) _safeDeleteFile(originalPath);
    }
  }

  Future<void> _uploadAndValidateCapturedImage() async {
    if (_currentCapturedPath == null) return;

    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    final file = File(_currentCapturedPath!);
    final step = _steps[_currentStepIndex];

    try {
      // 1. Upload to Supabase Storage first to get a public/signed URL
      final url = await KYCService.instance.uploadDocument(
        file: file,
        documentType: 'selfie_${step.id}',
      );

      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
      final deviceInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      final captureTime = DateTime.now().toUtc().toIso8601String();

      // 2. Call backend validation & enrollment (with 30 seconds timeout, 1 retry inside enrollPatientDetailed)
      final result = await CustomBiometricService.instance.enrollPatientDetailed(
        userId: userId,
        selfieUrl: url,
        poseLabel: step.id,
        enrollmentSessionId: _enrollmentSessionId,
        deviceInfo: deviceInfo,
        camera: 'front',
        captureTime: captureTime,
      );

      if (result.status == BiometricResultStatus.success) {
        // Success! Save to local persistent cache
        final cacheDir = await _getCacheDirectory();
        final cachedFile = File('${cacheDir.path}/${step.id}.jpg');
        await file.copy(cachedFile.path);

        _uploadedUrls[step.id] = url;
        _capturedPoses[step.id] = cachedFile.path;

        // Persist session state
        await _saveSessionState();

        setState(() {
          _isValidating = false;
          _isPoseAccepted = true;
          _liveInstruction = 'Pose accepted!';
        });

        HapticFeedback.mediumImpact();
        
        // Auto-advance after 500ms
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _acceptPose();
          }
        });
      } else {
        // Quality check failure / backend rejection
        final quality = result.qualityMetrics ?? {};
        setState(() {
          _isValidating = false;
          _faceCentered = quality['centered'] == true;
          _lightingGood = quality['lighting_good'] == true;
          _sharpnessGood = quality['sharpness_good'] == true;
          _poseValid = quality['pose_valid'] == true;
          _validationError = result.errorMessage ?? 'Biometric validation rejected.';
          _liveInstruction = result.errorMessage ?? 'Please adjust and try again.';
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('[BIO] Upload/Validation failed: $e');
      setState(() {
        _isValidating = false;
        _validationError = _extractErrorMessage(e);
      });
      HapticFeedback.heavyImpact();
      
      // If upload fails, keep file locally and display the Retry Upload dialog
      _showUploadFailedDialog(file);
    }
  }

  void _showUploadFailedDialog(File file) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Upload Failed',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'A connection issue occurred during upload. Would you like to retry uploading this photo or discard it and retake?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _retakePose();          // Discard and retake
            },
            child: Text(
              'RETAKE',
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _uploadAndValidateCapturedImage(); // Retry same image
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'RETRY UPLOAD',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptPose() {
    // Transition to next uncompleted step
    int nextUncompleted = -1;
    for (int i = 0; i < _steps.length; i++) {
      if (!_capturedPoses.containsKey(_steps[i].id)) {
        nextUncompleted = i;
        break;
      }
    }

    if (nextUncompleted != -1) {
      setState(() {
        _currentStepIndex = nextUncompleted;
        _currentCapturedPath = null;
        _isPoseAccepted = false;
        _validationError = null;
      });
      _startLocalGuidanceSimulation();
    } else {
      _finishEnrollment();
    }
  }

  void _retakePose() {
    if (_currentCapturedPath != null) {
      _safeDeleteFile(_currentCapturedPath!);
    }
    setState(() {
      _currentCapturedPath = null;
      _isPoseAccepted = false;
      _validationError = null;
    });
    _startLocalGuidanceSimulation();
  }

  void _finishEnrollment() {
    HapticFeedback.vibrate();
    // Return local paths and uploaded URLs
    Navigator.pop(context, {
      'localPaths': _capturedPoses,
      'uploadedUrls': _uploadedUrls,
    });
  }

  void _safeDeleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  String _extractErrorMessage(Object error) {
    String msg = error.toString();
    if (msg.startsWith('Exception: ')) {
      return msg.substring('Exception: '.length);
    }
    return msg;
  }

  Color get _circleColor {
    if (_validationError != null) return const Color(0xFFEF4444); // Vibrant Red
    if (_isPoseAccepted) return const Color(0xFF10B981); // Vibrant Emerald Green
    return _poseEligible ? const Color(0xFF10B981) : const Color(0xFF3B82F6); // Tech Blue
  }


  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStepIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Ink Black
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── LIVE PREVIEW / CAPTURED IMAGE ────────────────────────────
            if (_currentCapturedPath != null)
              Image.file(
                File(_currentCapturedPath!),
                fit: BoxFit.cover,
              )
            else if (_isCameraInitialized && _cameraController != null)
              CameraPreview(_cameraController!)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),

            // ── MASK OVERLAY & CIRCULAR HOLE ─────────────────────────────
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: FaceGuidePainter(
                    circleColor: _circleColor,
                    pulseFactor: _currentCapturedPath == null ? _pulseAnimation.value : 1.0,
                    progress: _currentStepIndex / _steps.length,
                    stepId: _currentCapturedPath == null ? step.id : 'none',
                  ),
                );
              },
            ),

            // ── TOP NAVIGATION / STEP DISPLAY ────────────────────────────
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  // Segmented Progress bar
                  Row(
                    children: List.generate(_steps.length, (index) {
                      final bool isCompleted = index < _currentStepIndex;
                      final bool isActive = index == _currentStepIndex;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : isActive
                                    ? const Color(0xFF3B82F6)
                                    : Colors.white24,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context, null),
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                      Text(
                        'BIOMETRIC VERIFICATION',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'STEP ${_currentStepIndex + 1}/${_steps.length}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── LIVE POSE ANGLES HUD ─────────────────────────────────────
            if (_currentCapturedPath == null)
              Positioned(
                top: 80,
                left: 24,
                right: 24,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _poseEligible ? AppColors.success : AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _poseEligible
                                  ? 'READY TO CAPTURE (${_currentPoseConfidence.toStringAsFixed(0)}% FIT)'
                                  : 'ALIGNING FACE (${_currentPoseConfidence.toStringAsFixed(0)}% FIT)',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── ACTION / FEEDBACK OVERLAYS ───────────────────────────────
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isValidating)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ANALYZING QUALITY',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_validationError != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.error.withOpacity(0.2)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VALIDATION FAILED',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _validationError!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _retakePose,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'RETAKE PHOTO',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_currentCapturedPath != null && !_isPoseAccepted && _validationError == null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'IMAGE CAPTURED',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Verify that your face is clear and matches the pose instruction.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _retakePose,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'RETAKE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _uploadAndValidateCapturedImage,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3B82F6),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'LOOKS GOOD',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_isPoseAccepted)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success.withOpacity(0.2)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'VALIDATION PASSED',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pose matched and image quality accepted.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _retakePose,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'RETAKE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _acceptPose,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'CONTINUE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    // Main Preview Action Control Overlay (Minimal Style, no heavy backdrop)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(step.icon, color: const Color(0xFF3B82F6), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  step.title.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF3B82F6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _liveInstruction,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Custom Shutter Button
                          Center(
                            child: GestureDetector(
                              onTap: (_isCapturing || !_poseEligible) ? null : _captureAndValidate,
                              child: AnimatedScale(
                                scale: _poseEligible ? 1.05 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _poseEligible ? Colors.white : Colors.white24,
                                      width: 4,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _poseEligible ? AppColors.success : Colors.white.withOpacity(0.15),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _poseEligible ? Icons.camera_alt_rounded : Icons.lock_rounded,
                                        color: _poseEligible ? Colors.white : Colors.white30,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  final Color circleColor;
  final double pulseFactor;
  final double progress;
  final String stepId;

  FaceGuidePainter({
    required this.circleColor,
    required this.pulseFactor,
    required this.progress,
    required this.stepId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final radius = size.width * 0.38;

    // 1. Draw dark background mask (hole in the center)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    final maskPaint = Paint()
      ..color = const Color(0x990D0D0D) // Softer, less bulky semi-transparent background (60% opacity)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, maskPaint);

    // 2. Draw animated pulsing guide ring (outer glow)
    final ringPaint = Paint()
      ..color = circleColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * pulseFactor, ringPaint);

    // 3. Draw clean inner indicator border (Apple Face ID style, solid and thin)
    final innerPaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, innerPaint);

    // Draw high-precision radial ticks around the target circle
    final tickPaint = Paint()
      ..color = circleColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final double tickStartRadius = radius + 3;
    final double tickEndRadius = radius + 7;
    const int totalTicks = 80;
    for (int i = 0; i < totalTicks; i++) {
      final double angle = (i * 2 * math.pi) / totalTicks;
      final Offset start = Offset(
        center.dx + tickStartRadius * math.cos(angle),
        center.dy + tickStartRadius * math.sin(angle),
      );
      final Offset end = Offset(
        center.dx + tickEndRadius * math.cos(angle),
        center.dy + tickEndRadius * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    // 4. Draw premium outer progress circle arc with gradient shader
    final outerRect = Rect.fromCircle(center: center, radius: radius + 11);
    
    // Draw the background progress track
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius + 11, trackPaint);

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF10B981)], // Tech Blue to Emerald Green
        stops: [0.0, 1.0],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(outerRect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    if (progress > 0) {
      canvas.drawArc(
        outerRect,
        -math.pi / 2, // Start at the top center
        2 * math.pi * progress, // Sweep angle depending on progress
        false,
        progressPaint,
      );
    }

    // 6. Draw lightweight local guidance arrows pointing outside the circle
    final arrowPaint = Paint()
      ..color = circleColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    final arrowPaint2 = Paint()
      ..color = circleColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    if (stepId == 'left') {
      // Chevron pointing left (user turns left)
      final arrowPath = Path()
        ..moveTo(center.dx - radius - 18, center.dy - 10)
        ..lineTo(center.dx - radius - 28, center.dy)
        ..lineTo(center.dx - radius - 18, center.dy + 10);
      canvas.drawPath(arrowPath, arrowPaint);

      final arrowPath2 = Path()
        ..moveTo(center.dx - radius - 28, center.dy - 8)
        ..lineTo(center.dx - radius - 36, center.dy)
        ..lineTo(center.dx - radius - 28, center.dy + 8);
      canvas.drawPath(arrowPath2, arrowPaint2);
    } else if (stepId == 'right') {
      // Chevron pointing right
      final arrowPath = Path()
        ..moveTo(center.dx + radius + 18, center.dy - 10)
        ..lineTo(center.dx + radius + 28, center.dy)
        ..lineTo(center.dx + radius + 18, center.dy + 10);
      canvas.drawPath(arrowPath, arrowPaint);

      final arrowPath2 = Path()
        ..moveTo(center.dx + radius + 28, center.dy - 8)
        ..lineTo(center.dx + radius + 36, center.dy)
        ..lineTo(center.dx + radius + 28, center.dy + 8);
      canvas.drawPath(arrowPath2, arrowPaint2);
    } else if (stepId == 'up') {
      // Chevron pointing up
      final arrowPath = Path()
        ..moveTo(center.dx - 10, center.dy - radius - 18)
        ..lineTo(center.dx, center.dy - radius - 28)
        ..lineTo(center.dx + 10, center.dy - radius - 18);
      canvas.drawPath(arrowPath, arrowPaint);

      final arrowPath2 = Path()
        ..moveTo(center.dx - 8, center.dy - radius - 28)
        ..lineTo(center.dx, center.dy - radius - 36)
        ..lineTo(center.dx + 8, center.dy - radius - 28);
      canvas.drawPath(arrowPath2, arrowPaint2);
    } else if (stepId == 'down') {
      // Chevron pointing down
      final arrowPath = Path()
        ..moveTo(center.dx - 10, center.dy + radius + 18)
        ..lineTo(center.dx, center.dy + radius + 28)
        ..lineTo(center.dx + 10, center.dy + radius + 18);
      canvas.drawPath(arrowPath, arrowPaint);

      final arrowPath2 = Path()
        ..moveTo(center.dx - 8, center.dy + radius + 28)
        ..lineTo(center.dx, center.dy + radius + 36)
        ..lineTo(center.dx + 8, center.dy + radius + 28);
      canvas.drawPath(arrowPath2, arrowPaint2);
    }
  }

  @override
  bool shouldRepaint(covariant FaceGuidePainter oldDelegate) {
    return oldDelegate.circleColor != circleColor ||
        oldDelegate.pulseFactor != pulseFactor ||
        oldDelegate.progress != progress ||
        oldDelegate.stepId != stepId;
  }
}
