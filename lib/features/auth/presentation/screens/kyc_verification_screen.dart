import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../../../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'premium_face_scan_screen.dart';
import 'package:path_provider/path_provider.dart';

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
        debugPrint('[KYC] Error prefilling fallback profile/patient data: $e');
      }

      final kyc = await _kycService.getKYCStatus();
      if (kyc != null && mounted) {
        setState(() {
          _fullName = kyc.fullName.isNotEmpty ? kyc.fullName : (fallbackName ?? '');
          _dateOfBirth = kyc.dateOfBirth;
          _idDocumentUrl = kyc.idDocumentUrl;
          _selfieUrl = kyc.selfieUrl;
        });

        if (kyc.status == KYCStatus.verified) {
          _showKYCVerifiedDialog();
        } else if (kyc.status == KYCStatus.pending) {
          _showKYCPendingDialog();
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

  void _showKYCVerifiedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 28),
            SizedBox(width: 10),
            Text(
              'Identity Verified',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Automated verification passed successfully:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF64748B)),
            ),
            SizedBox(height: 12),
            Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
              SizedBox(width: 8),
              Text('Government ID text matched', style: TextStyle(fontSize: 13)),
            ]),
            SizedBox(height: 6),
            Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
              SizedBox(width: 8),
              Text('Face matched against ID photo', style: TextStyle(fontSize: 13)),
            ]),
            SizedBox(height: 6),
            Row(children: [
              Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 16),
              SizedBox(width: 8),
              Text('Biometric profile enrolled', style: TextStyle(fontSize: 13)),
            ]),
            SizedBox(height: 14),
            Text(
              'You now have full access to all CareSync features.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.go(RouteNames.roleSelection);
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF121212),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showKYCPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pending, color: AppColors.warning),
            SizedBox(width: 8),
            Text('KYC Pending'),
          ],
        ),
        content: const Text(
          'Your KYC documents are under review. This usually takes 24-48 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.go(RouteNames.roleSelection);
            },
            child: const Text('Continue'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startGuidedFaceScan() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const PremiumFaceScanScreen()),
    );

    if (result != null && mounted) {
      final localPaths = Map<String, String>.from(result['localPaths'] ?? {});
      final uploadedUrls = Map<String, String>.from(result['uploadedUrls'] ?? {});

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guided scan completed. Poses loaded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _submitKYC() async {
    if (_idDocument == null && _idDocumentUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your ID document'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selfie == null && _selfieUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a selfie'),
          backgroundColor: AppColors.error,
        ),
      );
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
          debugPrint('[KYC] Poses already enrolled on the fly, skipping redundant upload.');
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
              debugPrint('[KYC] Smile pose enrollment warning: $e');
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
              debugPrint('[KYC] Angled view pose enrollment warning: $e');
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
        debugPrint('[KYC] Successfully cleaned up biometric cache.');
      } catch (e) {
        debugPrint('[KYC] Failed to clean up biometric cache: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Identity verified successfully!'),
            backgroundColor: AppColors.success,
          ),
        );

        // All gates passed — show verified dialog (no longer pending)
        _showKYCVerifiedDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit KYC: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Identity Verification',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textMain, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              AppColors.softBackground,
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info card (gradient style with security badge)
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        AppColors.primarySurface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryLight, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Secure Encryption',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMain,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your verification data is encrypted end-to-end. Poses are used solely to generate biometric search vectors for first responder identification.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textSub,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Document Sections Heading
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Required Identification Documents',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                ),

                // ID Document Section
                _buildDocumentSection(
                  title: 'Government ID Document',
                  subtitle: 'A clear photo of your official ID card or passport',
                  icon: Icons.badge_outlined,
                  file: _idDocument,
                  existingUrl: _idDocumentUrl,
                  onTap: _pickIdDocument,
                ),
                const SizedBox(height: 16),

                // Premium Guided Biometric Scan
                _buildDocumentSection(
                  title: 'Guided Biometric Scan',
                  subtitle: _capturedSupplementaryPoses != null
                      ? 'Guided biometric scan completed (${_capturedSupplementaryPoses!.length} poses captured) ✓'
                      : 'Guided multi-photo capture (5 poses required)',
                  icon: Icons.face_unlock_rounded,
                  file: _selfie,
                  existingUrl: _selfieUrl,
                  onTap: _startGuidedFaceScan,
                ),
                const SizedBox(height: 36),

                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E1B1B), Color(0xFF121212)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitKYC,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_outline_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Submit Secure Verification',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Skip Button
                Center(
                  child: TextButton(
                    onPressed: () {
                      context.go(RouteNames.roleSelection);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      foregroundColor: AppColors.textSub,
                    ),
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSub,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    final hasDocument = file != null || existingUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: hasDocument ? const Color(0xFFF0FDF4) : Colors.white,
        border: Border.all(
          color: hasDocument ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: hasDocument
                ? const Color(0xFF22C55E).withOpacity(0.04)
                : AppColors.shadowSoft.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasDocument
                        ? const Color(0xFFDCFCE7)
                        : AppColors.softBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasDocument ? Icons.check_circle_rounded : icon,
                    color: hasDocument ? const Color(0xFF22C55E) : AppColors.textSub,
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasDocument ? 'Pose registered ✓' : subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: hasDocument
                              ? const Color(0xFF16A34A)
                              : AppColors.textSub,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasDocument
                        ? const Color(0xFFDCFCE7).withOpacity(0.5)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasDocument ? Icons.edit_rounded : Icons.camera_alt_rounded,
                    color: hasDocument ? const Color(0xFF16A34A) : AppColors.textMain,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
