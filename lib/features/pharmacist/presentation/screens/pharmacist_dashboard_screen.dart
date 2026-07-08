import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../auth/providers/auth_provider.dart';

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

final recentBiometricLogsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await SupabaseService.instance.client
        .from('biometric_access_logs')
        .select('''
          *,
          patient_profile:profiles!target_patient_id(full_name)
        ''')
        .order('created_at', ascending: false)
        .limit(3);
    return List<Map<String, dynamic>>.from(res as List? ?? []);
  } catch (e) {
    debugPrint('Error loading biometric logs with profile join: $e');
    try {
      final resFallback = await SupabaseService.instance.client
          .from('biometric_access_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(3);
      return List<Map<String, dynamic>>.from(resFallback as List? ?? []);
    } catch (e2) {
      debugPrint('Error loading biometric access logs fallback: $e2');
      return [];
    }
  }
});

final pendingPrescriptionsCountProvider = FutureProvider<int>((ref) async {
  try {
    final res = await SupabaseService.instance.client
        .from('prescriptions')
        .select('id')
        .eq('status', 'active');
    return (res as List).length;
  } catch (e) {
    debugPrint('Error loading active prescriptions count: $e');
    return 0;
  }
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
  BiometricCancelToken? _activeCancelToken;
  bool _cooldownActive = false;
  Timer? _cooldownTimer;
  String _selectedFilter = 'All';

  static const _controlledKeywords = [
    'morphine',
    'fentanyl',
    'oxycodone',
    'codeine',
    'tramadol',
    'xanax',
    'diazepam',
    'adderall',
    'ritalin',
    'methadone',
    'vicodin',
    'hydrocodone',
    'buprenorphine',
    'alprazolam',
    'lorazepam',
  ];

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

  Future<void> _scanFace(BuildContext context) async {
    if (_cooldownActive) {
      debugPrint('[BIOMETRIC] Scan cooldown active. Ignoring duplicate request.');
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

      if (image == null) return; // User cancelled
      if (cancelToken.isCancelled) return;

      setState(() {
        _isIdentifying = true;
        _scanningStatus = 'Uploading face scan...';
      });

      // Call custom Biometric matching service
      final identifyResult = await CustomBiometricService.instance.identifyPatientDetailed(
        File(image.path),
        cancelToken: cancelToken,
      );

      if (cancelToken.isCancelled) return;
      if (!mounted) return;

      setState(() {
        _isIdentifying = false;
      });

      if (identifyResult.status == BiometricResultStatus.success && identifyResult.qrCodeId != null) {
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
        final pose = identifyResult.poseMatched ?? 'neutral';

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
        final friendlyMessage = CustomBiometricService.instance.mapStatusToErrorMessage(
          identifyResult.status,
          identifyResult.errorMessage,
          errorCode: identifyResult.errorCode,
        );

        if (identifyResult.status == BiometricResultStatus.noMatch) {
          _showNoMatchDialog(context, message: friendlyMessage);
        } else {
          _showErrorDialog(context, friendlyMessage);
        }
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

  void _showNoMatchDialog(BuildContext context, {String message = 'No Matching Patient Found'}) {
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
        content: Text(
          '$message\n\nWe could not find a matching patient profile in the CareSync database. Please check lighting, ensure the face is centered, or try searching manually.',
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
    final recentLogsAsync = ref.watch(recentBiometricLogsProvider);
    final pendingCountAsync = ref.watch(pendingPrescriptionsCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // MAIN CONTENT
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pharmacistTodayStatsProvider);
                ref.invalidate(pharmacistPendingPrescriptionsProvider);
                ref.invalidate(recentBiometricLogsProvider);
                ref.invalidate(pendingPrescriptionsCountProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. LIGHT HERO HEADER ─────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Navigation Row
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.pharmacist.withValues(alpha: 0.1),
                                      child: Text(
                                        profile.valueOrNull?.fullName.isNotEmpty == true
                                            ? profile.valueOrNull!.fullName.substring(0, 1).toUpperCase()
                                            : 'P',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.pharmacist,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Hello,',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: const Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          profile.valueOrNull?.fullName.isNotEmpty == true
                                              ? profile.valueOrNull!.fullName
                                              : 'Pharmacist',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF1E293B),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(height: 1, color: const Color(0xFFE5E7EB)),

                    // ── 2. SCROLLABLE CONTENT BODY ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Embedded Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              readOnly: true,
                              onTap: () {
                                context.push(RouteNames.pharmacistSearch);
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Iconsax.search_normal_1,
                                  color: Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                suffixIcon: InkWell(
                                  onTap: () {
                                    context.push(RouteNames.pharmacistDispense);
                                  },
                                  child: const Icon(
                                    Iconsax.scan,
                                    color: AppColors.pharmacist,
                                    size: 18,
                                  ),
                                ),
                                hintText: 'Search patient name, ID, or prescription...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Stats Row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.01),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.pharmacist.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Iconsax.health,
                                          color: AppColors.pharmacist,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        todayStats.valueOrNull?.toString() ?? '0',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        "Today's Dispensed",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.01),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Iconsax.document_text,
                                          color: Color(0xFF8B5CF6),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        pendingCountAsync.valueOrNull?.toString() ?? '0',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        "Pending Active",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Quick Actions
                          Text(
                            'Quick Actions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  context: context,
                                  icon: Iconsax.scan_barcode,
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
                                child: _buildActionCard(
                                  context: context,
                                  icon: Iconsax.frame_1,
                                  title: 'Scan Face',
                                  subtitle: 'AI biometric search',
                                  color: const Color(0xFF3B82F6),
                                  onTap: () => _scanFace(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  context: context,
                                  icon: Iconsax.user_search,
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
                                child: _buildActionCard(
                                  context: context,
                                  icon: Iconsax.clock,
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
                          const SizedBox(height: 20),

                          // Security Activity Log
                          recentLogsAsync.when(
                            loading: () => const SizedBox(),
                            error: (err, stack) => const SizedBox(),
                            data: (logs) {
                              if (logs.isEmpty) return const SizedBox();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Security Activity Log',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E293B),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    children: logs.map<Widget>((log) {
                                      final isSuccess = log['status'] == 'SUCCESS';
                                      final confidence = log['confidence_score'] as double?;
                                      final time = log['created_at'] != null 
                                          ? DateTime.parse(log['created_at'] as String) 
                                          : DateTime.now();

                                      final targetProfile = log['patient_profile'] as Map<String, dynamic>?;
                                      final patientName = targetProfile?['full_name'] as String? ?? log['actor_name'] as String? ?? 'Patient Scan';

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: (isSuccess ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isSuccess ? Iconsax.tick_circle : Iconsax.close_circle,
                                                color: isSuccess ? const Color(0xFF10B981) : Colors.red,
                                                size: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    patientName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    log['reason'] as String? ?? (isSuccess ? 'Verification successful' : 'Verification failed'),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
                                                      color: const Color(0xFF64748B),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                if (confidence != null)
                                                  Text(
                                                    '${(confidence * 100).toStringAsFixed(1)}% match',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSuccess ? const Color(0xFF10B981) : Colors.red,
                                                    ),
                                                  ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  DateFormat('h:mm a').format(time),
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 9,
                                                    color: const Color(0xFF94A3B8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              );
                            },
                          ),

                          // Pending Prescriptions Header
                          Text(
                            'Pending Prescriptions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Pending Prescriptions List
                          pendingRx.when(
                            loading: () => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            error: (err, stack) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Error loading prescriptions: $err',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            data: (list) {
                              if (list.isEmpty) {
                                return _buildEmptyState(context);
                              }

                              final filteredList = list.where((rx) {
                                if (_selectedFilter == 'Controlled') {
                                  return (rx['prescription_items'] as List? ?? []).any((item) {
                                    final name = (item['medicine_name'] as String? ?? '').toLowerCase();
                                    return _controlledKeywords.any((sub) => name.contains(sub));
                                  });
                                } else if (_selectedFilter == 'Urgent') {
                                  final diagnosis = (rx['diagnosis'] as String? ?? '').toLowerCase();
                                  return diagnosis.contains('urgent') || diagnosis.contains('severe') || diagnosis.contains('acute') || diagnosis.contains('heart') || diagnosis.contains('critical');
                                }
                                return true;
                              }).toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildFilterChip('All', list.length),
                                        const SizedBox(width: 8),
                                        _buildFilterChip(
                                          'Controlled',
                                          list.where((rx) => (rx['prescription_items'] as List? ?? []).any((item) {
                                            final name = (item['medicine_name'] as String? ?? '').toLowerCase();
                                            return _controlledKeywords.any((sub) => name.contains(sub));
                                          })).length,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildFilterChip(
                                          'Urgent',
                                          list.where((rx) {
                                            final diagnosis = (rx['diagnosis'] as String? ?? '').toLowerCase();
                                            return diagnosis.contains('urgent') || diagnosis.contains('severe') || diagnosis.contains('acute') || diagnosis.contains('heart') || diagnosis.contains('critical');
                                          }).length,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (filteredList.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24),
                                      child: Center(
                                        child: Text(
                                          'No pending prescriptions match the filter.',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF64748B),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: [
                                        ...filteredList.map((rx) {
                                          final patient = rx['patient'] as Map<String, dynamic>?;
                                          final patientProfile = patient?['profiles'] as Map<String, dynamic>?;
                                          final doctor = rx['doctor'] as Map<String, dynamic>?;
                                          final doctorProfile = doctor;
                                          final qrCodeId = patient?['qr_code_id'] as String?;
                                          final created = DateTime.parse(rx['created_at'] as String);
                                          final items = rx['prescription_items'] as List? ?? [];

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: const Color(0xFFE5E7EB)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.015),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
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
                                                            style: GoogleFonts.plusJakartaSans(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF1E293B),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Text(
                                                            'Dr. ${doctorProfile?['full_name'] ?? 'Unknown'} • ${DateFormat('MMM d, h:mm a').format(created)}',
                                                            style: GoogleFonts.plusJakartaSans(
                                                              fontSize: 11,
                                                              color: const Color(0xFF64748B),
                                                              fontWeight: FontWeight.w500,
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
                                                        icon: const Icon(Iconsax.tick_circle, size: 14),
                                                        label: Text(
                                                          'Dispense',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.pharmacist,
                                                          foregroundColor: Colors.white,
                                                          elevation: 0,
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  runSpacing: 6,
                                                  spacing: 6,
                                                  children: items.map<Widget>((item) {
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE6F4EA),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: AppColors.pharmacist.withValues(alpha: 0.15)),
                                                      ),
                                                      child: Text(
                                                        '${item['medicine_name']} (${item['dosage']})',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF0F766E),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
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
                            Iconsax.frame_1,
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
                      style: GoogleFonts.plusJakartaSans(
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

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.document_text,
              size: 32,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No pending prescriptions',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan patient QR or search manually to dispense',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.pharmacist : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.pharmacist : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white24 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.plusJakartaSans(
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
