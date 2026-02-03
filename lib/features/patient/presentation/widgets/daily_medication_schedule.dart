import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/patient_provider.dart';

class DailyMedicationSchedule extends ConsumerWidget {
  const DailyMedicationSchedule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);

    return prescriptionsAsync.when(
      data: (prescriptions) {
        // Flatten items from all prescriptions for today
        var allItems = prescriptions
            .expand((p) => p.items)
            .take(3) // Match mockup (3 items)
            .toList();

        // If empty, use mockup data as requested "for now"
        if (allItems.isEmpty) {
          return _buildMockupSchedule(context);
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: List.generate(allItems.length, (index) {
              final item = allItems[index];
              // Mocking status based on index as per reference
              final status = index == 0 ? 'Morning' : (index == 1 ? 'Taken' : 'Evening');
              final bulletColor = index == 0 ? Colors.indigo : (index == 1 ? Colors.green : Colors.blue);
              
              return Column(
                children: [
                  _MedicationRow(
                    name: item.medicineName,
                    dosage: item.dosage,
                    status: status,
                    bulletColor: bulletColor,
                  ),
                  if (index < allItems.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Divider(height: 1, color: AppColors.borderSoft),
                    ),
                ],
              );
            }),
          ),
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      )),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildMockupSchedule(BuildContext context) {
    final mockups = [
      {'name': 'Aspirin', 'dosage': '100mg', 'status': 'Morning', 'color': Colors.indigo},
      {'name': 'Lisinopril', 'dosage': '10mg', 'status': 'Taken', 'color': Colors.green},
      {'name': 'Metformin', 'dosage': '500mg', 'status': 'Evening', 'color': Colors.blue},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(mockups.length, (index) {
          final m = mockups[index];
          return Column(
            children: [
              _MedicationRow(
                name: m['name'] as String,
                dosage: m['dosage'] as String,
                status: m['status'] as String,
                bulletColor: m['color'] as Color,
              ),
              if (index < mockups.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1, color: AppColors.borderSoft),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Center(
        child: Text(
          'No medications scheduled.',
          style: TextStyle(color: AppColors.textSub, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final String name;
  final String dosage;
  final String status;
  final Color bulletColor;

  const _MedicationRow({
    required this.name,
    required this.dosage,
    required this.status,
    required this.bulletColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Widget? icon;

    switch (status) {
      case 'Taken':
        bg = AppColors.statusTakenBg;
        text = AppColors.statusTakenText;
        icon = const Icon(Icons.check, size: 12, color: AppColors.statusTakenText);
        break;
      case 'Morning':
        bg = AppColors.statusMorningBg;
        text = AppColors.statusMorningText;
        break;
      case 'Evening':
      default:
        bg = AppColors.statusEveningBg;
        text = AppColors.statusEveningText;
        break;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: bulletColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$name ',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain, fontSize: 14),
                ),
                TextSpan(
                  text: dosage,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSub, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const Text(
          '1 tablet   ',
          style: TextStyle(color: AppColors.textLight, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(width: 4),
              ],
              Text(
                status,
                style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
