import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/utils/image_quality_validator.dart';

class KYCVerificationScreen extends ConsumerStatefulWidget {
  const KYCVerificationScreen({super.key});

  @override
  ConsumerState<KYCVerificationScreen> createState() =>
      _KYCVerificationScreenState();
}

class _KYCVerificationScreenState extends ConsumerState<KYCVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  DateTime? _dateOfBirth;
  File? _idDocument;
  File? _selfie;
  File? _selfieSmile;
  File? _selfieAngle;
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
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingKYC() async {
    try {
      final kyc = await _kycService.getKYCStatus();
      if (kyc != null && mounted) {
        setState(() {
          _fullNameController.text = kyc.fullName;
          _dateOfBirth = kyc.dateOfBirth;
          _idDocumentUrl = kyc.idDocumentUrl;
          _selfieUrl = kyc.selfieUrl;
        });

        if (kyc.status == KYCStatus.verified) {
          _showKYCVerifiedDialog();
        } else if (kyc.status == KYCStatus.pending) {
          _showKYCPendingDialog();
        }
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

  Future<void> _takeSelfie() async {
    try {
      final photo = await _kycService.takePhoto();
      if (photo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing photo quality...'),
            duration: Duration(milliseconds: 1000),
          ),
        );
        
        final tempFile = File(photo.path);
        final qualityResult = await ImageQualityValidator.validateImage(tempFile);
        
        if (!qualityResult.isValid && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(qualityResult.errorMessage ?? 'Invalid photo quality'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        setState(() {
          _selfie = tempFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _takeSelfieSmile() async {
    try {
      final photo = await _kycService.takePhoto();
      if (photo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing photo quality...'),
            duration: Duration(milliseconds: 1000),
          ),
        );
        
        final tempFile = File(photo.path);
        final qualityResult = await ImageQualityValidator.validateImage(tempFile);
        
        if (!qualityResult.isValid && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(qualityResult.errorMessage ?? 'Invalid photo quality'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        setState(() {
          _selfieSmile = tempFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take smile photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _takeSelfieAngle() async {
    try {
      final photo = await _kycService.takePhoto();
      if (photo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analyzing photo quality...'),
            duration: Duration(milliseconds: 1000),
          ),
        );
        
        final tempFile = File(photo.path);
        final qualityResult = await ImageQualityValidator.validateImage(tempFile);
        
        if (!qualityResult.isValid && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(qualityResult.errorMessage ?? 'Invalid photo quality'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        setState(() {
          _selfieAngle = tempFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take profile angle photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: eighteenYearsAgo,
      firstDate: DateTime(1900),
      lastDate: eighteenYearsAgo,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      setState(() {
        _dateOfBirth = date;
      });
    }
  }

  Future<void> _submitKYC() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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

      if (_selfie != null) {
        selfieUrl = await _kycService.uploadDocument(
          file: _selfie!,
          documentType: 'selfie',
        );
      }

      // Submit KYC with automated OCR + biometric verification gates
      await _kycService.submitKYC(
        fullName: _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        idDocumentUrl: idDocUrl,
        selfieUrl: selfieUrl,
        idDocumentFile: _idDocument,
        selfieFile: _selfie,
      );

      // Upload and enroll supplementary poses (smile & angled_view)
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
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
      backgroundColor: const Color(0xFFFAFAFA), // Parchment surface background
      appBar: AppBar(
        title: Text(
          'Identity Verification',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF121212),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF121212), size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card (stark white card with brand left accent)
              IntrinsicHeight(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        color: const Color(0xFFFF5200),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.security_rounded, color: Color(0xFFFF5200), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Secure Encryption',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF121212),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your verification data is encrypted end-to-end. Poses are used solely to generate biometric search vectors for first responder identification.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Full Name Input
              TextFormField(
                controller: _fullNameController,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF121212)),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                  hintText: 'As shown on official ID',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF121212), width: 1.5),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date of Birth Input
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF64748B), size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Text(
                    _dateOfBirth != null
                        ? DateFormat('MMM dd, yyyy').format(_dateOfBirth!)
                        : 'Select your date of birth',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: _dateOfBirth != null ? const Color(0xFF121212) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Document Sections Heading
              Text(
                'Required Identification Documents',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF121212),
                ),
              ),
              const SizedBox(height: 14),

              // ID Document Section
              _buildDocumentSection(
                title: 'Government ID Document',
                subtitle: 'A clear photo of your official ID card or passport',
                icon: Icons.badge_outlined,
                file: _idDocument,
                existingUrl: _idDocumentUrl,
                onTap: _pickIdDocument,
              ),
              const SizedBox(height: 14),

              // Selfie - Neutral Face
              _buildDocumentSection(
                title: '1. Neutral Expression Selfie',
                subtitle: 'Capture your face straight-on, neutral look',
                icon: Icons.face_retouching_natural_rounded,
                file: _selfie,
                existingUrl: _selfieUrl,
                onTap: _takeSelfie,
              ),
              const SizedBox(height: 14),

              // Selfie - Smiling Face
              _buildDocumentSection(
                title: '2. Smiling Expression Selfie',
                subtitle: 'Capture your face smiling to verify key markers',
                icon: Icons.sentiment_satisfied_alt_rounded,
                file: _selfieSmile,
                onTap: _takeSelfieSmile,
              ),
              const SizedBox(height: 14),

              // Selfie - Angled View
              _buildDocumentSection(
                title: '3. Profile 30° Angled Selfie',
                subtitle: 'Turn head slightly to map depth of side features',
                icon: Icons.face_unlock_rounded,
                file: _selfieAngle,
                onTap: _takeSelfieAngle,
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitKYC,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF121212), // Ink black
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                    : Text(
                        'Submit Verification Poses',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Skip Button
              TextButton(
                onPressed: () {
                  context.go(RouteNames.roleSelection);
                },
                child: Text(
                  'Skip for now',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
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
    final hasDocument = file != null || existingUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: hasDocument ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasDocument
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasDocument ? Icons.check_circle_rounded : icon,
                    color: hasDocument ? const Color(0xFF22C55E) : const Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF121212),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasDocument ? 'Pose registered ✓' : subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: hasDocument
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  hasDocument ? Icons.edit_rounded : Icons.camera_alt_rounded,
                  color: const Color(0xFF121212),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
