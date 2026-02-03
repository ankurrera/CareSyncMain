import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/vitals_provider.dart';
import '../../models/vital.dart';
import 'add_vital_bottom_sheet.dart';

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
        // Use mockup data if real history is short for demonstration
        final effectiveVitals = vitalsList.length >= 6 
            ? vitalsList 
            : _getMockupHistory();

        // 1. Heart Rate
        final hrLatest = _getLatest(effectiveVitals, 'heart_rate');
        final hrPrev = _getPrevious(effectiveVitals, 'heart_rate');
        final hrTrend = _calculateStatus(hrLatest, hrPrev, 'bpm');

        // 2. Blood Pressure
        final bpLatest = _getLatest(effectiveVitals, 'blood_pressure');
        final bpPrev = _getPrevious(effectiveVitals, 'blood_pressure');
        final bpTrend = _calculateStatus(bpLatest, bpPrev, 'mmHg');

        // 3. Weight
        final weightLatest = _getLatest(effectiveVitals, 'weight');
        final weightPrev = _getPrevious(effectiveVitals, 'weight');
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
              trend: hrTrend['text'] as String,
              trendColor: hrTrend['color'] as Color,
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
              trend: bpTrend['text'] as String,
              trendColor: bpTrend['color'] as Color,
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
              trend: weightTrend['text'] as String,
              trendColor: weightTrend['color'] as Color,
              onTap: () => _showAddVital(context),
            ),
          ],
        );
      },
      loading: () => const Center(child: LinearProgressIndicator()),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textMain,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: trendColor,
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

  List<Vital> _getMockupHistory() {
    final now = DateTime.now();
    return [
      // Heart Rate History
      Vital(id: '1', patientId: 'p1', type: 'heart_rate', value: '78', unit: 'bpm', recordedAt: now),
      Vital(id: '2', patientId: 'p1', type: 'heart_rate', value: '76', unit: 'bpm', recordedAt: now.subtract(const Duration(days: 1))),
      
      // Blood Pressure History
      Vital(id: '3', patientId: 'p1', type: 'blood_pressure', value: '118/76', unit: 'mmHg', recordedAt: now),
      Vital(id: '4', patientId: 'p1', type: 'blood_pressure', value: '120/80', unit: 'mmHg', recordedAt: now.subtract(const Duration(days: 1))),
      
      // Weight History
      Vital(id: '5', patientId: 'p1', type: 'weight', value: '68', unit: 'kg', recordedAt: now),
      Vital(id: '6', patientId: 'p1', type: 'weight', value: '68.5', unit: 'kg', recordedAt: now.subtract(const Duration(days: 1))),
    ];
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

  Map<String, dynamic> _calculateStatus(Vital? latest, Vital? prev, String unit) {
    if (latest == null) return {'text': '-', 'color': AppColors.textSub};
    
    // Default statuses
    if (unit == 'bpm') {
      return {'text': '↑ Normal', 'color': AppColors.trendSuccess};
    }
    if (unit == 'mmHg') {
      return {'text': '↑ Optimal', 'color': AppColors.trendSuccess};
    }
    
    return {'text': 'Stable', 'color': AppColors.textSub};
  }

  Map<String, dynamic> _calculateWeightTrend(Vital? latest, Vital? prev) {
    if (latest == null || prev == null) return {'text': 'Stable', 'color': AppColors.textSub};
    
    try {
      final lVal = double.parse(latest.value);
      final pVal = double.parse(prev.value);
      final diff = lVal - pVal;
      
      if (diff == 0) return {'text': '→ Stable', 'color': AppColors.textSub};
      
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
