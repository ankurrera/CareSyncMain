import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/azure_face_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';

class FirstResponderDashboardScreen extends ConsumerStatefulWidget {
  const FirstResponderDashboardScreen({super.key});

  @override
  ConsumerState<FirstResponderDashboardScreen> createState() =>
      _FirstResponderDashboardScreenState();
}

class _FirstResponderDashboardScreenState
    extends ConsumerState<FirstResponderDashboardScreen>
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

  /// Launch camera to take patient photo and call Face ID matching API
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

      if (image == null) return; // User cancelled

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      // Update state message during identification
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

      // Call Azure Face matching service
      final matchResult = await AzureFaceService.instance.identifyPatient(File(image.path));

      if (!mounted) return;

      setState(() {
        _isIdentifying = false;
      });

      if (matchResult != null && matchResult['qr_code_id'] != null) {
        final qrCodeId = matchResult['qr_code_id'] as String;
        final fullName = matchResult['full_name'] as String;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Matched Patient: $fullName'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Direct navigation to patient emergency details screen
        context.push('${RouteNames.firstResponderEmergencyView}/$qrCodeId');
      } else {
        _showNoMatchDialog(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      debugPrint('[FR] Face scan identification error: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  void _showNoMatchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('No Match Found'),
          ],
        ),
        content: const Text(
          'We could not find a matching patient profile in the CareSync database.\n\nPlease check lighting, ensure the face is centered, or try scanning their physical QR code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scanFace(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.firstResponder,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Try Again'),
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
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Scanning Error'),
          ],
        ),
        content: Text(
          'An error occurred while matching the patient face:\n\n${message.contains("Exception:") ? message.split("Exception:").last : message}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ───────────────────────────────────────────────────────────────────
          // MAIN CONTENT
          // ───────────────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  DashboardHeader(
                    greeting: 'Ready to help,',
                    name: profile.valueOrNull?.fullName.isNotEmpty == true
                        ? profile.valueOrNull!.fullName
                        : 'First Responder',
                    subtitle: 'Quick access to emergency data',
                    roleColor: AppColors.firstResponder,
                  ),
                  const SizedBox(height: 32),

                  // Action panel header
                  const Text(
                    'Emergency Access Tools',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Scan Options (Row layout)
                  Row(
                    children: [
                      // Card 1: Scan QR
                      Expanded(
                        child: _buildScanCard(
                          title: 'SCAN QR',
                          subtitle: 'Physical band scan',
                          icon: Icons.qr_code_scanner_rounded,
                          gradient: const [
                            AppColors.firstResponder,
                            Color(0xFFDC2626),
                          ],
                          onTap: () {
                            context.push(RouteNames.firstResponderScan);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Card 2: Scan Face
                      Expanded(
                        child: _buildScanCard(
                          title: 'SCAN FACE',
                          subtitle: 'AI biometric search',
                          icon: Icons.face_retouching_helper_rounded,
                          gradient: const [
                            Color(0xFF1E3A8A), // Deep navy
                            Color(0xFF0284C7), // Sky blue
                          ],
                          onTap: () => _scanFace(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Recent Scans
                  const Text(
                    'Recent Emergency Scans',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No recent scans',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ───────────────────────────────────────────────────────────────────
          // FUTURISTIC GLASSMORPHIC SCANNING OVERLAY
          // ───────────────────────────────────────────────────────────────────
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
                            // Corner viewfinder brackets
                            _buildScannerCorners(),

                            // Scanning Line
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

                            // Scanning Face Silhouette (visual touch)
                            Center(
                              child: Icon(
                                Icons.face_rounded,
                                size: 120,
                                color: Colors.cyan.shade100.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Status Text
                      Text(
                        _scanningStatus,
                        style: const TextStyle(
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

  Widget _buildScanCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerCorners() {
    const double size = 28;
    const double thickness = 4;
    final Color color = Colors.cyanAccent.shade400;

    return Stack(
      children: [
        // Top Left
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
        // Top Right
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
        // Bottom Left
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
        // Bottom Right
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
