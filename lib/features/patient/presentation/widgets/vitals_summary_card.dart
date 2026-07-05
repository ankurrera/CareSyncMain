import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/vitals_provider.dart';
import '../../models/vital.dart';
import 'add_vital_bottom_sheet.dart';
import '../../../../core/widgets/loading_skeleton.dart';

class VitalsSummaryCard extends ConsumerWidget {
  const VitalsSummaryCard({super.key});

  void _showAddVital(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddVitalBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsAsync = ref.watch(patientVitalsProvider);

    return vitalsAsync.when(
      data: (vitalsList) {
        // 1. Heart Rate
        final hrLatest = _getLatest(vitalsList, 'heart_rate');
        final hrPrev = _getPrevious(vitalsList, 'heart_rate');
        final hrTrend = _calculateStatus(hrLatest, hrPrev, 'bpm');

        // 2. Blood Pressure
        final bpLatest = _getLatest(vitalsList, 'blood_pressure');
        final bpPrev = _getPrevious(vitalsList, 'blood_pressure');
        final bpTrend = _calculateStatus(bpLatest, bpPrev, 'mmHg');

        // 3. Weight
        final weightLatest = _getLatest(vitalsList, 'weight');
        final weightPrev = _getPrevious(vitalsList, 'weight');
        final weightTrend = _calculateWeightTrend(weightLatest, weightPrev);

        return Row(
          children: [
            _buildVitalCard(
              context,
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFF472B6),
              value: hrLatest?.value ?? '78',
              unit: 'bpm',
              label: 'Heart Rate',
              trend: hrLatest != null ? (hrTrend['text'] as String) : 'Normal',
              trendColor: hrLatest != null ? (hrTrend['color'] as Color) : AppColors.trendSuccess,
              onTap: () => _showAddVital(context),
            ),
            const SizedBox(width: 12),
            _buildVitalCard(
              context,
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF60A5FA),
              value: bpLatest?.value ?? '118/76',
              unit: 'mmHg',
              label: 'Blood Pressure',
              trend: bpLatest != null ? (bpTrend['text'] as String) : 'Optimal',
              trendColor: bpLatest != null ? (bpTrend['color'] as Color) : AppColors.trendSuccess,
              onTap: () => _showAddVital(context),
            ),
            const SizedBox(width: 12),
            _buildVitalCard(
              context,
              icon: Icons.monitor_weight_outlined,
              iconColor: const Color(0xFF34D399),
              value: weightLatest?.value ?? '68',
              unit: 'kg',
              label: 'Weight',
              trend: weightLatest != null ? (weightTrend['text'] as String) : 'Stable',
              trendColor: weightLatest != null ? (weightTrend['color'] as Color) : AppColors.textSub,
              onTap: () => _showAddVital(context),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          Expanded(child: LoadingSkeleton(height: 100, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: LoadingSkeleton(height: 100, radius: 20)),
          const SizedBox(width: 12),
          Expanded(child: LoadingSkeleton(height: 100, radius: 20)),
        ],
      ),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildVitalCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
    required String trend,
    required Color trendColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Label
              Row(
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Value and Unit Row (Wrapped in FittedBox to prevent overflow on narrow screens)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF121212),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Minimal Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trend,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: trendColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS for Dynamic Trends
  // ───────────────────────────────────────────────────────────────────────────

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

  Map<String, dynamic> _calculateStatus(Vital? latest, Vital? prev, String unit) {
    if (latest == null) return {'text': 'No record', 'color': AppColors.textSub};
    
    final val = latest.value;
    if (unit == 'bpm') {
      try {
        final rate = int.parse(val);
        if (rate >= 60 && rate <= 100) {
          return {'text': 'Normal', 'color': AppColors.trendSuccess};
        } else {
          return {'text': rate < 60 ? 'Low' : 'High', 'color': AppColors.trendWarning};
        }
      } catch (_) {
        return {'text': 'Logged', 'color': AppColors.trendSuccess};
      }
    }
    
    if (unit == 'mmHg') {
      try {
        final parts = val.split('/');
        final sys = int.parse(parts[0]);
        final dia = int.parse(parts[1]);
        if (sys < 120 && dia < 80) {
          return {'text': 'Optimal', 'color': AppColors.trendSuccess};
        } else if (sys <= 129 && dia < 80) {
          return {'text': 'Normal', 'color': AppColors.trendSuccess};
        } else {
          return {'text': 'Elevated', 'color': AppColors.trendWarning};
        }
      } catch (_) {
        return {'text': 'Logged', 'color': AppColors.trendSuccess};
      }
    }
    
    return {'text': 'Stable', 'color': AppColors.textSub};
  }

  Map<String, dynamic> _calculateWeightTrend(Vital? latest, Vital? prev) {
    if (latest == null) return {'text': 'No record', 'color': AppColors.textSub};
    if (prev == null) return {'text': 'Stable', 'color': AppColors.textSub};
    
    try {
      final lVal = double.parse(latest.value);
      final pVal = double.parse(prev.value);
      final diff = lVal - pVal;
      
      if (diff == 0) return {'text': 'Stable', 'color': AppColors.textSub};
      
      final diffStr = diff > 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);
      final arrow = diff > 0 ? '↑' : '↓';
      
      return {
        'text': '$arrow $diffStr kg',
        'color': diff > 0 ? Colors.orange : AppColors.trendWarning,
      };
    } catch (_) {
      return {'text': 'Stable', 'color': AppColors.textSub};
    }
  }
}
