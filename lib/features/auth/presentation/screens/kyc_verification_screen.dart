import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/logging/app_logger.dart';

import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../../../services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../../patient/providers/patient_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'premium_face_scan_screen.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../routing/screen_titles.dart';

class KYCVerificationScreen extends ConsumerStatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  ConsumerState<KYCVerificationScreen> createState() =>
      _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends ConsumerState<KYCVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _fullName = '';
  DateTime? _dateOfBirth;
  File? _idDocument;
  File? _selfie;
  File? _selfieSmile;
  File? _selfieAngle;
  Map<String, String>? _capturedSupplementaryPoses;
  bool _isLoading = false;
  String? _idDocumentUrl;
  String? _selfieUrl;

  final _kycService = KYCService.instance;

  @override
  void initState() {
    super.initState();
    _checkExistingKYC();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.tokens.error : context.tokens.accent,
      ),
    );
  }

  Future<void> _checkExistingKYC() async {
    try {
      // Fetch fallback name and date of birth from signup/profile & patient tables
      String? fallbackName;
      DateTime? fallbackDob;
      try {
        final profile = await SupabaseService.instance.getProfile();
        if (profile != null && profile['full_name'] != null) {
          fallbackName = profile['full_name'] as String;
        }
        final patient = await SupabaseService.instance.getPatientData();
        if (patient != null && patient['date_of_birth'] != null) {
          fallbackDob = DateTime.tryParse(patient['date_of_birth'] as String);
        }
      } catch (e) {
        AppLogger.warning(
          '[KYC] Error prefilling fallback profile/patient data',
          category: LogCategory.kyc,
          error: e,
        );
      }

      final kyc = await _kycService.getKYCStatus();
      if (kyc != null && mounted) {
        setState(() {
          _fullName =
              kyc.fullName.isNotEmpty ? kyc.fullName : (fallbackName ?? '');
          _dateOfBirth = kyc.dateOfBirth;
          _idDocumentUrl = kyc.idDocumentUrl;
          _selfieUrl = kyc.selfieUrl;
        });

        if (kyc.status == KYCStatus.verified) {
          _showKYCVerifiedSheet();
        } else if (kyc.status == KYCStatus.pending) {
          _showKYCPendingSheet();
        }
      } else if (mounted) {
        setState(() {
          _fullName = fallbackName ?? '';
          _dateOfBirth = fallbackDob;
        });
      }
    } catch (e) {
      // Ignore errors on init
    }
  }

  void _showKYCVerifiedSheet() {
    showAppSheet<void>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        Widget check(String label) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(Iconsax.tick_circle, color: t.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: t.textPrimary),
                ),
              ),
            ],
          ),
        );
        return AppSheetContent(
          icon: Iconsax.verify,
          title: 'Identity Verified',
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automated verification passed successfully:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  check('Government ID text matched'),
                  check('Face matched against ID photo'),
                  check('Biometric profile enrolled'),
                  const SizedBox(height: 8),
                  Text(
                    'You now have full access to all CareSync features.',
                    style: TextStyle(fontSize: 13, color: t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CSPrimaryButton(
              label: 'Get Started',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(RouteNames.patientDashboard);
              },
            ),
          ],
        );
      },
    );
  }

  void _showKYCPendingSheet() {
    showAppSheet<void>(
      context,
      builder:
          (ctx) => AppSheetContent(
            icon: Iconsax.clock,
            title: 'KYC Pending',
            message:
                'Your KYC documents are under review. This usually takes 24-48 hours.',
            children: [
              CSPrimaryButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go(RouteNames.roleSelection);
                },
              ),
            ],
          ),
    );
  }

  Future<void> _pickIdDocument() async {
    try {
      final image = await _kycService.pickImage();
      if (image != null && mounted) {
        setState(() {
          _idDocument = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) _snack('Failed to pick image: $e', error: true);
    }
  }

  Future<void> _startGuidedFaceScan() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const PremiumFaceScanScreen()),
    );

    if (result != null && mounted) {
      final localPaths = Map<String, String>.from(result['localPaths'] ?? {});
      final uploadedUrls = Map<String, String>.from(
        result['uploadedUrls'] ?? {},
      );

      setState(() {
        if (localPaths.containsKey('neutral')) {
          _selfie = File(localPaths['neutral']!);
        }
        if (localPaths.containsKey('smile')) {
          _selfieSmile = File(localPaths['smile']!);
        }
        if (localPaths.containsKey('left')) {
          _selfieAngle = File(localPaths['left']!);
        }
        _capturedSupplementaryPoses = localPaths;
        _selfieUrl = uploadedUrls['neutral'];
      });

      _snack('Guided scan completed. Poses loaded successfully!');
    }
  }

  Future<void> _submitKYC() async {
    if (_idDocument == null && _idDocumentUrl == null) {
      _snack('Please upload your ID document', error: true);
      return;
    }

    if (_selfie == null && _selfieUrl == null) {
      _snack('Please take a selfie', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload documents if new files were selected
      String idDocUrl = _idDocumentUrl ?? '';
      String selfieUrl = _selfieUrl ?? '';

      if (_idDocument != null) {
        idDocUrl = await _kycService.uploadDocument(
          file: _idDocument!,
          documentType: 'id_document',
        );
      }

      if (selfieUrl.isEmpty && _selfie != null) {
        selfieUrl = await _kycService.uploadDocument(
          file: _selfie!,
          documentType: 'selfie',
        );
      }

      // Submit KYC with automated OCR + biometric verification gates
      await _kycService.submitKYC(
        fullName: _fullName,
        dateOfBirth: _dateOfBirth ?? DateTime(2000, 1, 1),
        idDocumentUrl: idDocUrl,
        selfieUrl: selfieUrl,
        idDocumentFile: _idDocument,
        selfieFile: _selfie,
      );

      // Upload and enroll supplementary poses (smile, left, right, up, down)
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        if (_capturedSupplementaryPoses != null) {
          // Poses were already enrolled on the fly inside PremiumFaceScanScreen
          AppLogger.debug(
            '[KYC] Poses already enrolled on the fly, skipping redundant upload.',
            category: LogCategory.kyc,
          );
        } else {
          // Fallback to individual fields if guided scan was not used
          if (_selfieSmile != null) {
            try {
              final smileUrl = await _kycService.uploadDocument(
                file: _selfieSmile!,
                documentType: 'selfie_smile',
              );
              await _kycService.enrollFacePose(
                userId: userId,
                selfieUrl: smileUrl,
                poseLabel: 'smile',
              );
            } catch (e) {
              AppLogger.warning(
                '[KYC] Smile pose enrollment warning',
                category: LogCategory.kyc,
                error: e,
              );
            }
          }
          if (_selfieAngle != null) {
            try {
              final angleUrl = await _kycService.uploadDocument(
                file: _selfieAngle!,
                documentType: 'selfie_angle',
              );
              await _kycService.enrollFacePose(
                userId: userId,
                selfieUrl: angleUrl,
                poseLabel: 'angled_view',
              );
            } catch (e) {
              AppLogger.warning(
                '[KYC] Angled view pose enrollment warning',
                category: LogCategory.kyc,
                error: e,
              );
            }
          }
        }
      }

      // Clear biometric cache upon successful KYC submission
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final cacheDir = Directory('${docDir.path}/biometric_enrollment_cache');
        if (cacheDir.existsSync()) {
          cacheDir.deleteSync(recursive: true);
        }
        AppLogger.debug(
          '[KYC] Successfully cleaned up biometric cache.',
          category: LogCategory.kyc,
        );
      } catch (e) {
        AppLogger.warning(
          '[KYC] Failed to clean up biometric cache',
          category: LogCategory.kyc,
          error: e,
        );
      }

      // Refresh cached KYC status so the profile badge / dashboard reflect the
      // newly verified state. Without this, kycStatusProvider keeps serving the
      // stale pre-verification value and the app still shows "unverified".
      ref.invalidate(kycStatusProvider);
      ref.invalidate(isKycVerifiedProvider);

      if (mounted) {
        _snack('✅ Identity verified successfully!');
        // All gates passed — show verified sheet (no longer pending)
        _showKYCVerifiedSheet();
      }
    } catch (e) {
      if (mounted) _snack('Failed to submit KYC: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return CSScaffold(
      title: ScreenTitles.kycVerification,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageMargin,
          vertical: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card with security badge
              SquircleCard(
                radius: AppSpacing.squircleGrouped,
                color: t.tint,
                borderSide: BorderSide(color: t.accent.withValues(alpha: 0.3)),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.shield_tick,
                            color: t.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Secure Encryption',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: t.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your verification data is encrypted end-to-end. Poses are used solely to generate biometric search vectors for first responder identification.',
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Document Sections Heading
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Required Identification Documents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ),

              // ID Document Section
              _buildDocumentSection(
                title: 'Government ID Document',
                subtitle: 'A clear photo of your official ID card or passport',
                icon: Iconsax.card,
                file: _idDocument,
                existingUrl: _idDocumentUrl,
                onTap: _pickIdDocument,
              ),
              const SizedBox(height: 16),

              // Guided Biometric Scan
              _buildDocumentSection(
                title: 'Guided Biometric Scan',
                subtitle:
                    _capturedSupplementaryPoses != null
                        ? 'Guided biometric scan completed (${_capturedSupplementaryPoses!.length} poses captured) ✓'
                        : 'Guided multi-photo capture (5 poses required)',
                icon: Iconsax.scan,
                file: _selfie,
                existingUrl: _selfieUrl,
                onTap: _startGuidedFaceScan,
              ),
              const SizedBox(height: 36),

              // Submit Button
              CSPrimaryButton(
                label: 'Submit Secure Verification',
                icon: Iconsax.lock_1,
                loading: _isLoading,
                onPressed: _submitKYC,
              ),
              const SizedBox(height: 16),

              // Skip Button
              Center(
                child: TextButton(
                  onPressed: () {
                    context.go(RouteNames.roleSelection);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    foregroundColor: t.textSecondary,
                  ),
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required String subtitle,
    required IconData icon,
    File? file,
    String? existingUrl,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    final hasDocument = file != null || existingUrl != null;

    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      color: hasDocument ? t.tint : t.card,
      borderSide: BorderSide(
        color: hasDocument ? t.accent.withValues(alpha: 0.3) : t.divider,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  hasDocument ? t.accent.withValues(alpha: 0.15) : t.scaffold,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasDocument ? Iconsax.tick_circle : icon,
              color: hasDocument ? t.accent : t.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasDocument ? 'Pose registered ✓' : subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasDocument ? t.accent : t.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            hasDocument ? Iconsax.edit_2 : Iconsax.camera,
            color: hasDocument ? t.accent : t.textPrimary,
            size: 18,
          ),
        ],
      ),
    );
  }
}
