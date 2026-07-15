import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/logging/app_logger.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/custom_biometric_service.dart';
import '../../../shared/presentation/widgets/biometric_scan_hud.dart';
import '../../../auth/providers/auth_provider.dart';

final pharmacistTodayStatsProvider = FutureProvider<int>((ref) async {
  final pharmacistId = SupabaseService.instance.currentUserId;
  if (pharmacistId == null) return 0;

  final channel = SupabaseService.instance.client
      .channel('pharmacist_dispensing_stats_$pharmacistId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'dispensing_records',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'pharmacist_id',
          value: pharmacistId,
        ),
        callback: (payload) {
          ref.invalidateSelf();
        },
      );

  channel.subscribe();
  ref.onDispose(() {
    SupabaseService.instance.client.removeChannel(channel);
  });

  return await SupabaseService.instance.getTodaysDispensingCount();
});

final pharmacistPendingPrescriptionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final channel = SupabaseService.instance.client
          .channel('pharmacist_prescriptions_queue')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'prescriptions',
            callback: (payload) {
              ref.invalidateSelf();
              ref.invalidate(pendingPrescriptionsCountProvider);
            },
          );

      channel.subscribe();
      ref.onDispose(() {
        SupabaseService.instance.client.removeChannel(channel);
      });

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

final recentBiometricLogsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final res = await SupabaseService.instance.client
        .from('biometric_access_logs')
        .select('''
          *,
          patient:patients!target_patient_id(
            profiles(full_name)
          )
        ''')
        .order('created_at', ascending: false)
        .limit(3);
    return List<Map<String, dynamic>>.from(res as List? ?? []);
  } catch (e) {
    AppLogger.warning(
      'Error loading biometric logs with profile join',
      category: LogCategory.database,
      error: e,
    );
    try {
      final resFallback = await SupabaseService.instance.client
          .from('biometric_access_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(3);
      return List<Map<String, dynamic>>.from(resFallback as List? ?? []);
    } catch (e2) {
      AppLogger.warning(
        'Error loading biometric access logs fallback',
        category: LogCategory.database,
        error: e2,
      );
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
    AppLogger.warning(
      'Error loading active prescriptions count',
      category: LogCategory.database,
      error: e,
    );
    return 0;
  }
});

class PharmacistDashboardScreen extends ConsumerStatefulWidget {
  const PharmacistDashboardScreen({super.key});

  @override
  ConsumerState<PharmacistDashboardScreen> createState() =>
      _PharmacistDashboardScreenState();
}

class _PharmacistDashboardScreenState
    extends ConsumerState<PharmacistDashboardScreen> {
  bool _isIdentifying = false;
  String _scanningStatus = 'Initializing...';
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
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _activeCancelToken?.cancel();
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
        final pose = identifyResult.poseMatched ?? 'neutral';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Matched Patient: $fullName (${confidence.toStringAsFixed(1)}% confidence, pose: $pose)',
            ),
            backgroundColor: context.tokens.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );

        context.push(RouteNames.pharmacistDispense, extra: qrCodeId);
      } else {
        final friendlyMessage = CustomBiometricService.instance
            .mapStatusToErrorMessage(
              identifyResult.status,
              identifyResult.errorMessage,
              errorCode: identifyResult.errorCode,
            );

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
        '[PHARM] Face scan identification error',
        category: LogCategory.biometric,
        error: e,
      );
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
          '$message\n\nWe could not find a matching patient profile in the CareSync database. Please check lighting, ensure the face is centered, or try searching manually.',
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
    final profile = ref.watch(currentProfileProvider);
    final todayStats = ref.watch(pharmacistTodayStatsProvider);
    final pendingRx = ref.watch(pharmacistPendingPrescriptionsProvider);
    final recentLogsAsync = ref.watch(recentBiometricLogsProvider);
    final pendingCountAsync = ref.watch(pendingPrescriptionsCountProvider);

    return Scaffold(
      backgroundColor: t.scaffold,
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
                    // ── 1. HERO HEADER ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      color: t.card,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: GestureDetector(
                            onTap: () => context.push(RouteNames.profile),
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: t.divider,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: t.tint,
                                    child: Text(
                                      profile
                                                  .valueOrNull
                                                  ?.fullName
                                                  .isNotEmpty ==
                                              true
                                          ? profile.valueOrNull!.fullName
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'P',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: t.accent,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hello,',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: t.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile
                                                    .valueOrNull
                                                    ?.fullName
                                                    .isNotEmpty ==
                                                true
                                            ? profile.valueOrNull!.fullName
                                            : 'Pharmacist',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: t.textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: t.tint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Iconsax.arrow_right_3,
                                    size: 14,
                                    color: t.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(height: 1, color: t.divider),

                    // ── 2. SCROLLABLE CONTENT BODY ────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Embedded Search Bar
                          GestureDetector(
                            onTap: () {
                              context.push(RouteNames.pharmacistSearch);
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: t.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: t.divider),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Iconsax.search_normal_1,
                                    color: t.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Search patient name, ID, or prescription...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: t.textSecondary.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () {
                                      context.push(
                                        RouteNames.pharmacistDispense,
                                      );
                                    },
                                    child: Icon(
                                      Iconsax.scan,
                                      color: t.accent,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Stats Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Iconsax.health,
                                  value:
                                      todayStats.valueOrNull?.toString() ?? '0',
                                  label: "Today's Dispensed",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Iconsax.document_text,
                                  value:
                                      pendingCountAsync.valueOrNull
                                          ?.toString() ??
                                      '0',
                                  label: 'Pending Active',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Quick Actions
                          _sectionTitle('Quick Actions'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  icon: Iconsax.scan_barcode,
                                  title: 'Scan QR',
                                  subtitle: 'Scan patient QR',
                                  onTap: () {
                                    context.push(RouteNames.pharmacistDispense);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionCard(
                                  icon: Iconsax.frame_1,
                                  title: 'Scan Face',
                                  subtitle: 'AI biometric search',
                                  onTap: () => _scanFace(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionCard(
                                  icon: Iconsax.user_search,
                                  title: 'Search Patient',
                                  subtitle: 'Lookup manually',
                                  onTap: () {
                                    context.push(RouteNames.pharmacistSearch);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionCard(
                                  icon: Iconsax.clock,
                                  title: 'History',
                                  subtitle: 'Dispense records',
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
                                  _sectionTitle('Security Activity Log'),
                                  const SizedBox(height: 12),
                                  Column(
                                    children:
                                        logs.map<Widget>((log) {
                                          final isSuccess =
                                              log['status'] == 'SUCCESS';
                                          final confidence =
                                              log['confidence_score']
                                                  as double?;
                                          final time =
                                              log['created_at'] != null
                                                  ? DateTime.parse(
                                                    log['created_at'] as String,
                                                  )
                                                  : DateTime.now();

                                          final targetPatient =
                                              log['patient']
                                                  as Map<String, dynamic>?;
                                          final targetProfile =
                                              targetPatient != null
                                                  ? targetPatient['profiles']
                                                      as Map<String, dynamic>?
                                                  : log['patient_profile']
                                                      as Map<String, dynamic>?;
                                          final patientName =
                                              targetProfile?['full_name']
                                                  as String? ??
                                              'Biometric Scan';
                                          final statusColor =
                                              isSuccess ? t.accent : t.error;

                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: SquircleCard(
                                              radius:
                                                  AppSpacing.squircleGrouped,
                                              borderSide: BorderSide(
                                                color: t.divider,
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: statusColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      isSuccess
                                                          ? Iconsax.tick_circle
                                                          : Iconsax
                                                              .close_circle,
                                                      color: statusColor,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          patientName,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                t.textPrimary,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 1,
                                                        ),
                                                        Text(
                                                          (() {
                                                            final reasonStr =
                                                                log['reason']
                                                                    as String?;
                                                            if (reasonStr !=
                                                                    null &&
                                                                reasonStr
                                                                    .isNotEmpty) {
                                                              try {
                                                                final decoded =
                                                                    json.decode(
                                                                          reasonStr,
                                                                        )
                                                                        as Map<
                                                                          String,
                                                                          dynamic
                                                                        >;
                                                                final msg =
                                                                    decoded['message']
                                                                        as String?;
                                                                final errCode =
                                                                    decoded['error_code']
                                                                        as String?;
                                                                final isCache =
                                                                    decoded['source'] ==
                                                                    'cache';

                                                                if (errCode ==
                                                                    'SERVER_ERROR') {
                                                                  return 'Internal server error';
                                                                } else if (msg !=
                                                                        null &&
                                                                    msg.isNotEmpty) {
                                                                  return msg;
                                                                } else if (isCache) {
                                                                  return 'Patient identified successfully (cached)';
                                                                } else if (errCode !=
                                                                        null &&
                                                                    errCode
                                                                        .isNotEmpty) {
                                                                  final formatted =
                                                                      errCode
                                                                          .replaceAll(
                                                                            '_',
                                                                            ' ',
                                                                          )
                                                                          .toLowerCase();
                                                                  if (formatted
                                                                      .isNotEmpty) {
                                                                    return formatted[0]
                                                                            .toUpperCase() +
                                                                        formatted
                                                                            .substring(
                                                                              1,
                                                                            );
                                                                  }
                                                                  return formatted;
                                                                }
                                                              } catch (_) {
                                                                return reasonStr;
                                                              }
                                                            }
                                                            return isSuccess
                                                                ? 'Verification successful'
                                                                : 'Verification failed';
                                                          })(),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                t.textSecondary,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      if (confidence != null)
                                                        Text(
                                                          '${(confidence * 100).toStringAsFixed(1)}% match',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: statusColor,
                                                          ),
                                                        ),
                                                      const SizedBox(height: 1),
                                                      Text(
                                                        DateFormat(
                                                          'h:mm a',
                                                        ).format(time),
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              t.textSecondary,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
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
                          _sectionTitle('Pending Prescriptions'),
                          const SizedBox(height: 12),

                          // Pending Prescriptions List
                          pendingRx.when(
                            loading:
                                () => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            error:
                                (err, stack) => Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Error loading prescriptions: $err',
                                      style: TextStyle(
                                        color: t.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            data: (list) {
                              if (list.isEmpty) {
                                return _buildEmptyState(context);
                              }

                              final filteredList =
                                  list.where((rx) {
                                    if (_selectedFilter == 'Controlled') {
                                      return (rx['prescription_items']
                                                  as List? ??
                                              [])
                                          .any((item) {
                                            final name =
                                                (item['medicine_name']
                                                            as String? ??
                                                        '')
                                                    .toLowerCase();
                                            return _controlledKeywords.any(
                                              (sub) => name.contains(sub),
                                            );
                                          });
                                    } else if (_selectedFilter == 'Urgent') {
                                      final diagnosis =
                                          (rx['diagnosis'] as String? ?? '')
                                              .toLowerCase();
                                      return diagnosis.contains('urgent') ||
                                          diagnosis.contains('severe') ||
                                          diagnosis.contains('acute') ||
                                          diagnosis.contains('heart') ||
                                          diagnosis.contains('critical');
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
                                          list
                                              .where(
                                                (
                                                  rx,
                                                ) => (rx['prescription_items']
                                                            as List? ??
                                                        [])
                                                    .any((item) {
                                                      final name =
                                                          (item['medicine_name']
                                                                      as String? ??
                                                                  '')
                                                              .toLowerCase();
                                                      return _controlledKeywords
                                                          .any(
                                                            (sub) => name
                                                                .contains(sub),
                                                          );
                                                    }),
                                              )
                                              .length,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildFilterChip(
                                          'Urgent',
                                          list.where((rx) {
                                            final diagnosis =
                                                (rx['diagnosis'] as String? ??
                                                        '')
                                                    .toLowerCase();
                                            return diagnosis.contains(
                                                  'urgent',
                                                ) ||
                                                diagnosis.contains('severe') ||
                                                diagnosis.contains('acute') ||
                                                diagnosis.contains('heart') ||
                                                diagnosis.contains('critical');
                                          }).length,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (filteredList.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'No pending prescriptions match the filter.',
                                          style: TextStyle(
                                            color: t.textSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children:
                                          filteredList.map((rx) {
                                            return _buildPendingCard(
                                              context,
                                              rx,
                                            );
                                          }).toList(),
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
          // SCANNING LOADER OVERLAY (dark by design)
          if (_isIdentifying) BiometricScanHud(status: _scanningStatus),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    final t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: t.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: t.accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: t.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return SizedBox(
      height: 76,
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(color: t.divider),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: t.accent, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(BuildContext context, Map<String, dynamic> rx) {
    final t = context.tokens;
    final patient = rx['patient'] as Map<String, dynamic>?;
    final patientProfile = patient?['profiles'] as Map<String, dynamic>?;
    final doctor = rx['doctor'] as Map<String, dynamic>?;
    final qrCodeId = patient?['qr_code_id'] as String?;
    final created = DateTime.parse(rx['created_at'] as String);
    final items = rx['prescription_items'] as List? ?? [];
    final patientName =
        patientProfile?['full_name'] as String? ?? 'Unknown Patient';
    final initials =
        patientName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide.none,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dr. ${doctor?['full_name'] ?? 'Unknown'}  ·  ${DateFormat('MMM d, h:mm a').format(created)}',
                    style: TextStyle(fontSize: 11, color: t.textSecondary),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      runSpacing: 4,
                      spacing: 4,
                      children:
                          items.map<Widget>((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: t.tint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item['medicine_name'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: t.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (qrCodeId != null)
              GestureDetector(
                onTap: () {
                  context.push(RouteNames.pharmacistDispense, extra: qrCodeId);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Dispense',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.accentOn,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.document_text,
              size: 28,
              color: t.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'No pending prescriptions',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan patient QR or search manually to dispense.',
              style: TextStyle(
                color: t.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final t = context.tokens;
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
          color: isSelected ? t.accent : t.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? t.accent : t.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? t.accentOn : t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:
                    isSelected ? t.accentOn.withValues(alpha: 0.25) : t.divider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? t.accentOn : t.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
