import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/custom_biometric_service.dart';
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
        final pose = matchResult['pose_matched'] as String? ?? 'neutral';

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
        _showNoMatchDialog(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      debugPrint('[Emergency] Face scan identification error: $e');
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
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(
          'Emergency Center',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Banner ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF121212),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: Text(
                    'Access critical patient medical information instantly during health crises.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
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
          if (_isIdentifying)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Viewfinder Frame
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.cyan.shade400.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Stack(
                          children: [
                            _buildScannerCorners(),
                            AnimatedBuilder(
                              animation: _scannerController,
                              builder: (context, child) {
                                return Positioned(
                                  top: _scannerController.value * 252,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent.shade400,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.cyanAccent.shade400
                                              .withValues(alpha: 0.7),
                                          blurRadius: 12,
                                          spreadRadius: 2.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Center(
                              child: Icon(
                                Icons.face_rounded,
                                size: 120,
                                color:
                                    Colors.cyan.shade100.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        _scanningStatus,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "MATCHING BIOMETRIC REGISTRY",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
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

  Widget _buildScannerCorners() {
    const double size = 28;
    const double thickness = 4;
    final Color color = Colors.cyanAccent.shade400;

    return Stack(
      children: [
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: thickness),
                left: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: thickness),
                right: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: thickness),
                left: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: thickness),
                right: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
