import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../providers/patient_provider.dart';
import '../../models/prescription.dart';

class DailyMedicationSchedule extends ConsumerStatefulWidget {
  const DailyMedicationSchedule({super.key});

  @override
  ConsumerState<DailyMedicationSchedule> createState() =>
      _DailyMedicationScheduleState();
}

class _DailyMedicationScheduleState
    extends ConsumerState<DailyMedicationSchedule> {
  final Set<String> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final todayMedsAsync = ref.watch(todayMedicationsProvider);

    return todayMedsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        final displayItems = items.take(3).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(displayItems.length, (index) {
            final item = displayItems[index];
            final isChecked = _checkedItems.contains(item.id);

            return _buildMedicationCard(item, isChecked);
          }),
        );
      },
      loading:
          () => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingSkeleton(height: 72, radius: 20),
              SizedBox(height: 12),
              LoadingSkeleton(height: 72, radius: 20),
            ],
          ),
      error: (err, _) => _buildEmptyState(),
    );
  }

  Widget _buildMedicationCard(PrescriptionItem item, bool isChecked) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        color: isChecked ? t.scaffold : t.card,
        borderSide: BorderSide(color: t.divider, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Interactive Checkbox with haptics
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _checkedItems.remove(item.id);
                  } else {
                    _checkedItems.add(item.id);
                    HapticFeedback.lightImpact();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? t.accent : t.card,
                  border: Border.all(
                    color: isChecked ? t.accent : t.divider,
                    width: 1.5,
                  ),
                ),
                child:
                    isChecked
                        ? Icon(Icons.check_rounded, size: 13, color: t.accentOn)
                        : null,
              ),
            ),
            const SizedBox(width: 14),
            // Medicine Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.medicineName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isChecked ? t.textSecondary : t.textPrimary,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        size: 11,
                        color: t.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.dosage} • ${item.frequency}',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Status Pill Badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isChecked ? t.scaffold : t.tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isChecked ? 'Taken' : 'Due',
                style: TextStyle(
                  color: isChecked ? t.textSecondary : t.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              'No medications scheduled today.',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your daily medicine schedule will appear here.',
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
}
