import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/adaptive_card_container.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../providers/patient_provider.dart';
import '../../models/prescription.dart';

class DailyMedicationSchedule extends ConsumerStatefulWidget {
  const DailyMedicationSchedule({super.key});

  @override
  ConsumerState<DailyMedicationSchedule> createState() => _DailyMedicationScheduleState();
}

class _DailyMedicationScheduleState extends ConsumerState<DailyMedicationSchedule> {
  final Set<String> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final todayMedsAsync = ref.watch(todayMedicationsProvider);

    return todayMedsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // Limit to top 3 items to prevent layout bloat on Dashboard
        final displayItems = items.take(3).toList();

        return AdaptiveCardContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: List.generate(displayItems.length, (index) {
              final item = displayItems[index];
              final isChecked = _checkedItems.contains(item.id);

              return Column(
                children: [
                  _buildMedicationRow(item, isChecked),
                  if (index < displayItems.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                ],
              );
            }),
          ),
        );
      },
      loading: () => const AdaptiveCardContainer(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            LoadingSkeleton(height: 20, width: double.infinity),
            SizedBox(height: 12),
            LoadingSkeleton(height: 20, width: double.infinity),
            SizedBox(height: 12),
            LoadingSkeleton(height: 20, width: double.infinity),
          ],
        ),
      ),
      error: (err, _) => _buildEmptyState(),
    );
  }

  Widget _buildMedicationRow(PrescriptionItem item, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          // Premium Interactive Checkbox with Haptics
          GestureDetector(
            onTap: () {
              setState(() {
                if (isChecked) {
                  _checkedItems.remove(item.id);
                } else {
                  _checkedItems.add(item.id);
                  HapticFeedback.lightImpact(); // Tactile feedback
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? const Color(0xFF10B981) : Colors.white,
                border: Border.all(
                  color: isChecked ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isChecked ? const Color(0xFF94A3B8) : const Color(0xFF121212),
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.dosage} • ${item.frequency}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Dispensed status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isChecked
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFFF4F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isChecked ? 'Taken' : 'Due',
              style: GoogleFonts.plusJakartaSans(
                color: isChecked ? const Color(0xFF065F46) : const Color(0xFFFF5200),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.document_text, color: Color(0xFF94A3B8), size: 28),
            const SizedBox(height: 8),
            Text(
              'No medications scheduled today.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
