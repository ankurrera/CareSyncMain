import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../routing/screen_titles.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../../services/emergency_audit_service.dart';
import '../../../shared/presentation/widgets/biometric_scan_hud.dart';

class PatientEmergencyScreen extends ConsumerStatefulWidget {
  const PatientEmergencyScreen({super.key});

  @override
  ConsumerState<PatientEmergencyScreen> createState() =>
      _PatientEmergencyScreenState();
}

class _PatientEmergencyScreenState extends ConsumerState<PatientEmergencyScreen>
    with SingleTickerProviderStateMixin {
  bool _isIdentifying = false;
  String _scanningStatus = 'Initializing...';
  late AnimationController _scannerController;
  BiometricCancelToken? _activeCancelToken;
  bool _cooldownActive = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _activeCancelToken?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanFace() async {
    if (_cooldownActive) {
      AppLogger.debug(
        '[BIOMETRIC] Scan cooldown active. Ignoring duplicate request.',
        category: LogCategory.biometric,
      );
      return;
    }

    _activeCancelToken?.cancel();
    final cancelToken = BiometricCancelToken();
    _activeCancelToken = cancelToken;

    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;
      if (cancelToken.isCancelled) return;

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _isIdentifying && !cancelToken.isCancelled) {
          setState(() {
            _scanningStatus = 'Analyzing biometric coordinates...';
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _isIdentifying && !cancelToken.isCancelled) {
          setState(() {
            _scanningStatus = 'Searching CareSync registry...';
          });
        }
      });

      final identifyResult = await CustomBiometricService.instance
          .identifyPatientDetailed(File(image.path), cancelToken: cancelToken);

      if (cancelToken.isCancelled) return;
      if (!mounted) return;

      setState(() {
        _isIdentifying = false;
      });

      if (identifyResult.status == BiometricResultStatus.success &&
          identifyResult.qrCodeId != null) {
        setState(() {
          _cooldownActive = true;
        });
        _cooldownTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _cooldownActive = false;
            });
          }
        });

        final qrCodeId = identifyResult.qrCodeId!;
        final fullName = identifyResult.fullName ?? 'Unknown';
        final confidence = identifyResult.confidence ?? 100.0;
        final patientId = identifyResult.patientId;
        final pose = identifyResult.poseMatched ?? 'neutral';

        await EmergencyAuditService.instance.logFaceScan(
          patientId: patientId,
          status: 'Success',
          confidence: confidence.toDouble(),
        );

        HapticFeedback.mediumImpact();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Matched Patient: $fullName (${confidence.toStringAsFixed(1)}% confidence, pose: $pose)',
            ),
            backgroundColor: context.tokens.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );

        context.push('${RouteNames.patientEmergencyView}/$qrCodeId');
      } else {
        final friendlyMessage = CustomBiometricService.instance
            .mapStatusToErrorMessage(
              identifyResult.status,
              identifyResult.errorMessage,
              errorCode: identifyResult.errorCode,
            );

        await EmergencyAuditService.instance.logFaceScan(
          patientId: null,
          status: 'Failed',
          confidence: 0.0,
          reason: friendlyMessage,
        );

        HapticFeedback.heavyImpact();

        if (identifyResult.status == BiometricResultStatus.noMatch) {
          _showNoMatchSheet(message: friendlyMessage);
        } else {
          _showErrorSheet(friendlyMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      AppLogger.error(
        '[Emergency] Face scan identification error',
        category: LogCategory.emergency,
        error: e,
      );

      await EmergencyAuditService.instance.logFaceScan(
        patientId: null,
        status: 'Failed',
        confidence: 0.0,
        reason: 'Scanning Error',
      );

      HapticFeedback.heavyImpact();

      _showErrorSheet(e.toString());
    }
  }

  Future<void> _showNoMatchSheet({
    String message = 'No Matching Patient Found',
  }) async {
    final retry = await showConfirmSheet(
      context,
      icon: Iconsax.warning_2,
      title: 'No Match Found',
      message:
          '$message\n\nWe could not find a matching patient profile in the CareSync database. Please check lighting, ensure the face is centered, or try scanning their physical QR code.',
      confirmLabel: 'Try Again',
      cancelLabel: 'Close',
    );
    if (retry) _scanFace();
  }

  void _showErrorSheet(String message) {
    showAlertSheet(
      context,
      icon: Iconsax.close_circle,
      title: 'Scanning Error',
      message:
          'An error occurred while matching the patient face:\n\n${message.contains("Exception:") ? message.split("Exception:").last : message}',
      buttonLabel: 'Close',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CSScaffold(
      title: ScreenTitles.patientEmergencyCenter,
      automaticBack: false,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Banner ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: SquircleCard(
                    radius: AppSpacing.squircleGrouped,
                    color: t.tint,
                    borderSide: BorderSide(
                      color: t.accent.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.danger,
                            color: t.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'First Responder Mode',
                                style: TextStyle(
                                  color: t.accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Access critical patient medical information instantly during health crises.',
                                style: TextStyle(
                                  color: t.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Lookup Tools',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildToolCard(
                        context,
                        title: 'Scan Patient Face',
                        description:
                            'Identify an unconscious patient using AI face matching.',
                        icon: Iconsax.frame_1,
                        onTap: () => _scanFace(),
                      ),
                      const SizedBox(height: 14),
                      _buildToolCard(
                        context,
                        title: 'Scan Patient QR Code',
                        description:
                            'Scan physical emergency card or bracelet QR.',
                        icon: Iconsax.scan,
                        onTap:
                            () => context.push(RouteNames.patientEmergencyScan),
                      ),
                      const SizedBox(height: 14),
                      _buildToolCard(
                        context,
                        title: 'My Emergency Medical ID',
                        description:
                            'View or share your personal emergency pass.',
                        icon: Iconsax.personalcard,
                        onTap: () => context.push(RouteNames.patientQrCode),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isIdentifying) BiometricScanHud(status: _scanningStatus),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
            child: Icon(icon, color: t.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Iconsax.arrow_right_1, color: t.textSecondary, size: 18),
        ],
      ),
    );
  }
}
