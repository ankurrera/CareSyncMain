import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../shared/presentation/widgets/dashboard_header.dart';
import '../../../shared/presentation/widgets/quick_action_card.dart';

final pharmacistTodayStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTodaysDispensingCount();
});

final pharmacistPendingPrescriptionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await SupabaseService.instance.client
      .from('prescriptions')
      .select('''
        *,
        patient:patients!inner(
          qr_code_id,
          profiles!inner(full_name, email)
        ),
        doctor:profiles!doctor_id(full_name),
        prescription_items(*)
      ''')
      .eq('status', 'active')
      .order('created_at', ascending: false)
      .limit(5);
  return List<Map<String, dynamic>>.from(response);
});

class PharmacistDashboardScreen extends ConsumerStatefulWidget {
  const PharmacistDashboardScreen({super.key});

  @override
  ConsumerState<PharmacistDashboardScreen> createState() => _PharmacistDashboardScreenState();
}

class _PharmacistDashboardScreenState extends ConsumerState<PharmacistDashboardScreen>
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

      if (image == null) return; // User cancelled

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      // Call custom Biometric matching service
      final matchResult = await CustomBiometricService.instance.identifyPatient(File(image.path));

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
            content: Text('Matched Patient: $fullName (${confidence.toStringAsFixed(1)}% confidence, pose: $pose)'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Navigate directly to dispense screen with the patient's QR ID
        context.push(RouteNames.pharmacistDispense, extra: qrCodeId);
      } else {
        _showNoMatchDialog(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isIdentifying = false;
        });
      }
      debugPrint('[PHARM] Face scan identification error: $e');
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
          'We could not find a matching patient profile in the CareSync database.\n\nPlease check lighting, ensure the face is centered, or try searching manually.',
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
              backgroundColor: AppColors.pharmacist,
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
    final todayStats = ref.watch(pharmacistTodayStatsProvider);
    final pendingRx = ref.watch(pharmacistPendingPrescriptionsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // MAIN CONTENT
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pharmacistTodayStatsProvider);
                ref.invalidate(pharmacistPendingPrescriptionsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    DashboardHeader(
                      greeting: 'Hello,',
                      name: profile.valueOrNull?.fullName.isNotEmpty == true 
                          ? profile.valueOrNull!.fullName 
                          : 'Pharmacist',
                      subtitle: 'Dispense & track medications',
                      roleColor: AppColors.pharmacist,
                    ),
                    const SizedBox(height: 24),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'Today\'s Dispensed',
                            todayStats.valueOrNull?.toString() ?? '0',
                            Icons.medication_outlined,
                            AppColors.pharmacist,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              context.push(RouteNames.pharmacistDispense);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: _buildStatCard(
                              context,
                              'Scan to Dispense',
                              '→',
                              Icons.qr_code_scanner_rounded,
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: QuickActionCard(
                            icon: Icons.qr_code_scanner_rounded,
                            title: 'Scan QR',
                            subtitle: 'Scan patient QR',
                            color: AppColors.pharmacist,
                            onTap: () {
                              context.push(RouteNames.pharmacistDispense);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: QuickActionCard(
                            icon: Icons.face,
                            title: 'Scan Face',
                            subtitle: 'AI biometric search',
                            color: const Color(0xFF1E3A8A), // Deep navy
                            onTap: () => _scanFace(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: QuickActionCard(
                            icon: Icons.search_rounded,
                            title: 'Search Patient',
                            subtitle: 'Lookup manually',
                            color: AppColors.primary,
                            onTap: () {
                              context.push(RouteNames.pharmacistSearch);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: QuickActionCard(
                            icon: Icons.history_rounded,
                            title: 'History',
                            subtitle: 'Dispense records',
                            color: AppColors.info,
                            onTap: () {
                              context.push(RouteNames.pharmacistHistory);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Pending Prescriptions Header
                    const Text(
                      'Pending Prescriptions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pending Prescriptions List
                    pendingRx.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error loading prescriptions: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return _buildEmptyState(context);
                        }

                        return Column(
                          children: list.map((rx) {
                            final patient = rx['patient'] as Map<String, dynamic>?;
                            final patientProfile = patient?['profiles'] as Map<String, dynamic>?;
                            final doctor = rx['doctor'] as Map<String, dynamic>?;
                            final doctorProfile = doctor;
                            final qrCodeId = patient?['qr_code_id'] as String?;
                            final created = DateTime.parse(rx['created_at'] as String);
                            final items = rx['prescription_items'] as List? ?? [];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              patientProfile?['full_name'] as String? ?? 'Unknown Patient',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Dr. ${doctorProfile?['full_name'] ?? 'Unknown'} • ${DateFormat('MMM d, h:mm a').format(created)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (qrCodeId != null)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            context.push(RouteNames.pharmacistDispense, extra: qrCodeId);
                                          },
                                          icon: const Icon(Icons.check_rounded, size: 16),
                                          label: const Text('Dispense'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.pharmacist,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    runSpacing: 6,
                                    spacing: 6,
                                    children: items.map<Widget>((item) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.pharmacist.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${item['medicine_name']} (${item['dosage']})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.pharmacist,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // SCANNING LOADER OVERLAY
          if (_isIdentifying)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.face,
                            size: 80,
                            color: Colors.white,
                          ),
                          AnimatedBuilder(
                            animation: _scannerController,
                            builder: (context, child) {
                              return Positioned(
                                top: 25 + (_scannerController.value * 100),
                                left: 25,
                                right: 25,
                                child: Container(
                                  height: 3,
                                  color: Colors.redAccent,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _scanningStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.medication_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No pending prescriptions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan patient QR or search manually to dispense',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
