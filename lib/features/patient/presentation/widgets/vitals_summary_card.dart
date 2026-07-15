import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../providers/vitals_provider.dart';
import '../../models/vital.dart';
import 'add_vital_bottom_sheet.dart';
import '../../../../services/encryption_service.dart';
import '../../../../core/widgets/loading_skeleton.dart';

class VitalsSummaryCard extends ConsumerWidget {
  const VitalsSummaryCard({super.key});

  void _showVitalOptions(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (context) => const AddVitalBottomSheet(),
    );
  }

  // Maps a status key to a token colour.
  Color _statusColor(BuildContext context, String status) {
    final t = context.tokens;
    switch (status) {
      case 'good':
        return t.accent;
      case 'warn':
        return t.error;
      default:
        return t.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final vitalsAsync = ref.watch(patientVitalsProvider);
    return vitalsAsync.when(
      data: (vitalsList) {
        final hrLatest = _getLatest(vitalsList, 'heart_rate');
        final hrTrend = _calculateStatus(hrLatest, 'bpm');

        final bpLatest = _getLatest(vitalsList, 'blood_pressure');
        final bpTrend = _calculateStatus(bpLatest, 'mmHg');

        final weightLatest = _getLatest(vitalsList, 'weight');
        final weightPrev = _getPrevious(vitalsList, 'weight');
        final weightTrend = _calculateWeightTrend(weightLatest, weightPrev);

        String decrypt(Vital? v) {
          if (v?.value == null) return 'No data logged yet.';
          try {
            return EncryptionService.instance.decryptDeterministic(
              encryptedData: v!.value,
              patientId: v.patientId,
            );
          } catch (_) {
            return v!.value;
          }
        }

        final hrVal = decrypt(hrLatest);
        final bpVal = decrypt(bpLatest);
        final weightVal = decrypt(weightLatest);

        final hrLabel =
            hrLatest != null ? (hrTrend['text'] as String) : 'No Data';
        final bpLabel =
            bpLatest != null ? (bpTrend['text'] as String) : 'No Data';
        final weightLabel =
            weightLatest != null ? (weightTrend['text'] as String) : 'No Data';

        final hrColor = _statusColor(
          context,
          hrLatest != null ? hrTrend['status'] as String : 'neutral',
        );
        final bpColor = _statusColor(
          context,
          bpLatest != null ? bpTrend['status'] as String : 'neutral',
        );
        final weightColor = _statusColor(
          context,
          weightLatest != null ? weightTrend['status'] as String : 'neutral',
        );

        final bool showNoDataNotice =
            hrVal == 'No data logged yet.' ||
            bpVal == 'No data logged yet.' ||
            weightVal == 'No data logged yet.';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildVitalCard(
                  context,
                  icon: Iconsax.heart,
                  value: hrVal,
                  unit: 'bpm',
                  label: 'Heart Rate',
                  trend: hrLabel,
                  trendColor: hrColor,
                  onTap: () => _showVitalOptions(context),
                ),
                const SizedBox(width: 12),
                _buildVitalCard(
                  context,
                  icon: Iconsax.drop,
                  value: bpVal,
                  unit: 'mmHg',
                  label: 'Blood Pressure',
                  trend: bpLabel,
                  trendColor: bpColor,
                  onTap: () => _showVitalOptions(context),
                ),
                const SizedBox(width: 12),
                _buildVitalCard(
                  context,
                  icon: Iconsax.weight,
                  value: weightVal,
                  unit: 'kg',
                  label: 'Weight',
                  trend: weightLabel,
                  trendColor: weightColor,
                  onTap: () => _showVitalOptions(context),
                ),
              ],
            ),
            if (showNoDataNotice) ...[
              const SizedBox(height: 12),
              SquircleCard(
                radius: AppSpacing.squircleGrouped,
                borderSide: BorderSide(color: t.divider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Iconsax.info_circle, size: 16, color: t.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap a card to log your vitals manually.',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading:
          () => const Row(
            children: [
              Expanded(child: LoadingSkeleton(height: 100, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: LoadingSkeleton(height: 100, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: LoadingSkeleton(height: 100, radius: 20)),
            ],
          ),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildVitalCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required String trend,
    required Color trendColor,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    final bool isNoData = value == 'No data logged yet.';
    final String displayValue = isNoData ? '--' : value;
    final String displayUnit = isNoData ? '' : unit;

    return Expanded(
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(color: t.divider),
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: t.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (displayUnit.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Text(
                      displayUnit,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trend,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Vital? _getLatest(List<Vital> vitals, String type) {
    final filtered = vitals.where((v) => v.type == type).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return filtered.first;
  }

  Vital? _getPrevious(List<Vital> vitals, String type) {
    final filtered = vitals.where((v) => v.type == type).toList();
    if (filtered.length < 2) return null;
    filtered.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return filtered[1];
  }

  Map<String, dynamic> _calculateStatus(Vital? latest, String unit) {
    if (latest == null) return {'text': 'No record', 'status': 'neutral'};

    final val = latest.value;
    if (unit == 'bpm') {
      try {
        final rate = int.parse(val);
        if (rate >= 60 && rate <= 100) {
          return {'text': 'Normal', 'status': 'good'};
        } else {
          return {'text': rate < 60 ? 'Low' : 'High', 'status': 'warn'};
        }
      } catch (_) {
        return {'text': 'Logged', 'status': 'good'};
      }
    }

    if (unit == 'mmHg') {
      try {
        final parts = val.split('/');
        final sys = int.parse(parts[0]);
        final dia = int.parse(parts[1]);
        if (sys < 120 && dia < 80) {
          return {'text': 'Optimal', 'status': 'good'};
        } else if (sys <= 129 && dia < 80) {
          return {'text': 'Normal', 'status': 'good'};
        } else {
          return {'text': 'Elevated', 'status': 'warn'};
        }
      } catch (_) {
        return {'text': 'Logged', 'status': 'good'};
      }
    }

    return {'text': 'Stable', 'status': 'neutral'};
  }

  Map<String, dynamic> _calculateWeightTrend(Vital? latest, Vital? prev) {
    if (latest == null) return {'text': 'No record', 'status': 'neutral'};
    if (prev == null) return {'text': 'Stable', 'status': 'neutral'};

    try {
      final curW = double.parse(latest.value);
      final preW = double.parse(prev.value);
      final diff = curW - preW;
      if (diff.abs() < 0.1) {
        return {'text': 'Stable', 'status': 'neutral'};
      }
      final direction = diff > 0 ? '+' : '';
      return {
        'text': '$direction${diff.toStringAsFixed(1)} kg',
        'status': diff > 0 ? 'warn' : 'good',
      };
    } catch (_) {
      return {'text': 'Stable', 'status': 'neutral'};
    }
  }
}
