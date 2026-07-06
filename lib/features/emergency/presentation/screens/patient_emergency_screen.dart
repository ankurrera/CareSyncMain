import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../../services/emergency_audit_service.dart';
import '../../../auth/providers/auth_provider.dart';

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
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _scanFace(BuildContext context) async {
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

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _isIdentifying) {
          setState(() {
            _scanningStatus = 'Analyzing biometric coordinates...';
          });
        }
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _isIdentifying) {
          setState(() {
            _scanningStatus = 'Searching CareSync registry...';
          });
        }
      });

      final matchResult = await CustomBiometricService.instance
          .identifyPatient(File(image.path));

      if (!mounted) return;

      setState(() {
        _isIdentifying = false;
      });

      if (matchResult != null && matchResult['qr_code_id'] != null) {
        final qrCodeId = matchResult['qr_code_id'] as String;
        final fullName = matchResult['full_name'] as String;
        final confidence = matchResult['confidence'] as num? ?? 100.0;
        final patientId = matchResult['patient_id'] as String?;
        final pose = matchResult['pose_matched'] as String? ?? 'neutral';

        // Log successful face scan
        await EmergencyAuditService.instance.logFaceScan(
          patientId: patientId,
          status: 'Success',
          confidence: confidence.toDouble(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Matched Patient: $fullName (${confidence.toStringAsFixed(1)}% confidence, pose: $pose)',
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );

        context.push('${RouteNames.patientEmergencyView}/$qrCodeId');
      } else {
        // Log failed face scan
        await EmergencyAuditService.instance.logFaceScan(
          patientId: null,
          status: 'Failed',
          confidence: 0.0,
          reason: 'Unknown Patient',
        );

        _showNoMatchDialog(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      debugPrint('[Emergency] Face scan identification error: $e');

      // Log errored face scan
      await EmergencyAuditService.instance.logFaceScan(
        patientId: null,
        status: 'Failed',
        confidence: 0.0,
        reason: 'Unknown Patient',
      );

      _showErrorDialog(context, e.toString());
    }
  }

  void _showNoMatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Iconsax.warning_2, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              'No Match Found',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'We could not find a matching patient profile in the CareSync database.\n\nPlease check lighting, ensure the face is centered, or try scanning their physical QR code.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scanFace(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5200),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Try Again', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(
              'Scanning Error',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'An error occurred while matching the patient face:\n\n${message.contains("Exception:") ? message.split("Exception:").last : message}',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Emergency Center',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF121212),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF121212)),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Banner ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF5F0), Color(0xFFFFEBE3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD4C2), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFE3D6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Iconsax.danger,
                            color: Color(0xFFFF5200),
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
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFFD43D00),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Access critical patient medical information instantly during health crises.',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF8C3814),
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
                  padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section 1: Emergency Lookup Tools ──────────────────
                      Text(
                        'Emergency Lookup Tools',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF121212),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tool cards
                      _buildToolCard(
                        context,
                        title: 'Scan Patient Face',
                        description: 'Identify an unconscious patient using AI face matching.',
                        icon: Iconsax.frame_1,
                        color: const Color(0xFFFF5200),
                        onTap: () => _scanFace(context),
                      ),
                      const SizedBox(height: 14),
                      _buildToolCard(
                        context,
                        title: 'Scan Patient QR Code',
                        description: 'Scan physical emergency card or bracelet QR.',
                        icon: Iconsax.scan,
                        color: const Color(0xFF121212),
                        onTap: () =>
                            context.push(RouteNames.patientEmergencyScan),
                      ),
                      const SizedBox(height: 14),
                      _buildToolCard(
                        context,
                        title: 'My Emergency Medical ID',
                        description: 'View or share your personal emergency pass.',
                        icon: Iconsax.personalcard,
                        color: const Color(0xFF64748B),
                        onTap: () => context.push(RouteNames.patientQrCode),
                      ),
                      const SizedBox(height: 32),

                      // ── Section 2: First Aid Quick Guide ───────────────────
                      Text(
                        'First Aid Quick Guide',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF121212),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildGuideTile(
                        context,
                        title: 'CPR (Cardiopulmonary Resuscitation)',
                        details: 'Place hands in center of chest. Push hard and fast (100-120 compressions/min). Give 2 rescue breaths after every 30 compressions.',
                        icon: Iconsax.heart_tick,
                      ),
                      const SizedBox(height: 12),
                      _buildGuideTile(
                        context,
                        title: 'Choking (Heimlich Maneuver)',
                        details: 'Stand behind the person. Wrap arms around waist. Make a fist and press hard into the abdomen with quick, upward thrusts.',
                        icon: Iconsax.warning_2,
                      ),
                      const SizedBox(height: 12),
                      _buildGuideTile(
                        context,
                        title: 'Severe Bleeding Control',
                        details: 'Apply firm, direct pressure to the wound with a clean cloth. Elevate the injured area. Use a tourniquet if bleeding is life-threatening.',
                        icon: Iconsax.danger,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Biometric search scanning overlay ──────────────────────────────
          // ── Biometric search scanning overlay ──────────────────────────────
          if (_isIdentifying)
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: Colors.black.withOpacity(0.55),
                    child: Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B).withOpacity(0.85), // Premium zinc/graphite
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Apple Face ID style breathing brackets and icon
                            AnimatedBuilder(
                              animation: _scannerController,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 84,
                                      height: 84,
                                      child: CustomPaint(
                                        painter: _FaceBracketPainter(
                                          color: AppColors.primary,
                                          animationValue: _scannerController.value,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.face_unlock_rounded, // Professional biometric lock silhouette
                                      color: Colors.white.withOpacity(0.4 + (_scannerController.value * 0.5)),
                                      size: 46,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'FACE ID SCAN',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Inline loader and status text (highly compact and clinical)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _scanningStatus.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121212),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Iconsax.arrow_right_1,
                color: Color(0xFF94A3B8), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideTile(
    BuildContext context, {
    required String title,
    required String details,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFEF4444), size: 20),
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
                const SizedBox(height: 6),
                Text(
                  details,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

// Apple Face ID-inspired camera corner brackets custom painter
class _FaceBracketPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  _FaceBracketPainter({required this.color, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3 + (animationValue * 0.7))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final length = 12.0;

    // Top Left Corner
    canvas.drawLine(const Offset(0, 0), Offset(0, length), paint);
    canvas.drawLine(const Offset(0, 0), Offset(length, 0), paint);

    // Top Right Corner
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);

    // Bottom Left Corner
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);

    // Bottom Right Corner
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _FaceBracketPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}
