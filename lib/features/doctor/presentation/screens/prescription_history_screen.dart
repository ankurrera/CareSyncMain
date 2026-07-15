import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../routing/screen_titles.dart';

// Provider for doctor prescriptions list
final doctorPrescriptionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>((
      ref,
      patientId,
    ) async {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return [];

      var query = supabase
          .from('prescriptions')
          .select('''
        *,
        prescription_items(*),
        patient:patients!inner(
          id,
          profiles!inner(full_name, email)
        )
      ''')
          .eq('doctor_id', userId);

      if (patientId != null && patientId.isNotEmpty) {
        query = query.eq('patient_id', patientId);
      }

      final prescriptions = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(prescriptions);
    });

class PrescriptionHistoryScreen extends ConsumerWidget {
  final String? patientId;
  final String? patientName;

  const PrescriptionHistoryScreen({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final prescriptionsAsync = ref.watch(
      doctorPrescriptionsProvider(patientId),
    );
    final dateFormat = DateFormat('MMM d, yyyy');

    return CSScaffold(
      title:
          patientName != null
              ? '$patientName\'s Prescriptions'
              : ScreenTitles.doctorHistory,
      actions: [
        IconButton(
          icon: Icon(Iconsax.refresh, color: t.textPrimary, size: 18),
          onPressed:
              () => ref.invalidate(doctorPrescriptionsProvider(patientId)),
        ),
      ],
      body: prescriptionsAsync.when(
        loading:
            () => Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
            ),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.warning_2, size: 48, color: t.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load prescriptions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    CSPrimaryButton(
                      label: 'Retry',
                      fullWidth: false,
                      onPressed:
                          () => ref.invalidate(
                            doctorPrescriptionsProvider(patientId),
                          ),
                    ),
                  ],
                ),
              ),
            ),
        data: (prescriptions) {
          if (prescriptions.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh:
                () async =>
                    ref.invalidate(doctorPrescriptionsProvider(patientId)),
            color: t.accent,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              itemCount: prescriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final rx = prescriptions[index];
                final patient = rx['patient'] as Map<String, dynamic>?;
                final profile = patient?['profiles'] as Map<String, dynamic>?;
                final patientName =
                    profile?['full_name'] as String? ?? 'Unknown Patient';
                final items = rx['prescription_items'] as List? ?? [];
                final status = rx['status'] as String? ?? 'active';
                final createdAt = DateTime.parse(rx['created_at'] as String);

                final patientInitial =
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';

                return SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  borderSide: BorderSide(color: t.divider),
                  padding: EdgeInsets.zero,
                  onTap: () {
                    context.push(
                      RouteNames.doctorPatientRecord,
                      extra: {
                        'patientId': patient?['id'] as String? ?? '',
                        'patientName': patientName,
                      },
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Header: Patient Info + Status Badge
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: t.tint,
                                  child: Text(
                                    patientInitial,
                                    style: TextStyle(
                                      color: t.accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
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
                                        patientName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: t.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        dateFormat.format(createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: t.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusBadge(context, status),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 2. Diagnosis Card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: t.scaffold,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DIAGNOSIS',
                                    style: t.monoMeta.copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: t.textSecondary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    rx['diagnosis'] as String? ??
                                        'No diagnosis',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3. Medications wraps
                            if (items.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children:
                                    items.map<Widget>((item) {
                                      final isDispensed =
                                          item['is_dispensed'] as bool? ??
                                          false;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isDispensed ? t.tint : t.scaffold,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color:
                                                isDispensed
                                                    ? t.accent.withValues(
                                                      alpha: 0.3,
                                                    )
                                                    : t.divider,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isDispensed)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 10,
                                                color: t.accent,
                                              ),
                                            if (isDispensed)
                                              const SizedBox(width: 4),
                                            Text(
                                              '${item['medicine_name']} ${item['dosage']}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDispensed
                                                        ? t.accent
                                                        : t.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 4. Visibility Footer info
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: t.scaffold,
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(AppSpacing.squircleGrouped),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              rx['is_public'] == true
                                  ? Iconsax.global
                                  : Iconsax.lock_1,
                              size: 14,
                              color:
                                  rx['is_public'] == true
                                      ? t.accent
                                      : t.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              rx['is_public'] == true
                                  ? 'Visible to first responders'
                                  : 'Private',
                              style: TextStyle(
                                fontSize: 10,
                                color: t.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.card,
                shape: BoxShape.circle,
                border: Border.all(color: t.divider),
              ),
              child: Icon(
                Iconsax.document_text,
                size: 40,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Prescriptions Issued',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prescriptions you issue to patients will appear in this history list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final t = context.tokens;
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = t.textSecondary;
        label = 'Completed';
        break;
      case 'cancelled':
        color = t.error;
        label = 'Cancelled';
        break;
      default:
        color = t.accent;
        label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: t.monoMeta.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
