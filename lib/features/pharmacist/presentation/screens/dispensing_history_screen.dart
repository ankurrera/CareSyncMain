import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/screen_titles.dart';

final dispensingHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return [];

  final records = await supabase
      .from('dispensing_records')
      .select('''
        *,
        prescription:prescriptions!inner(
          diagnosis,
          prescription_items(medicine_name, dosage)
        ),
        patient:patients!inner(
          profiles!inner(full_name, email)
        )
      ''')
      .eq('pharmacist_id', userId)
      .order('dispensed_at', ascending: false);

  return List<Map<String, dynamic>>.from(records);
});

class DispensingHistoryScreen extends ConsumerWidget {
  const DispensingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final historyAsync = ref.watch(dispensingHistoryProvider);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return CSScaffold(
      title: ScreenTitles.pharmacistHistory,
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.warning_2,
                    size: 64,
                    color: t.error.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text('Error: $error', style: TextStyle(color: t.textPrimary)),
                  TextButton(
                    onPressed: () => ref.invalidate(dispensingHistoryProvider),
                    child: Text('Retry', style: TextStyle(color: t.accent)),
                  ),
                ],
              ),
            ),
        data: (records) {
          if (records.isEmpty) {
            return _buildEmptyState(context);
          }

          // Group by date
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final record in records) {
            final date = dateFormat.format(
              DateTime.parse(record['dispensed_at'] as String),
            );
            grouped.putIfAbsent(date, () => []).add(record);
          }

          return ListView.builder(
            padding: AppSpacing.screenPadding,
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final date = grouped.keys.elementAt(index);
              final dayRecords = grouped[date]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) const SizedBox(height: 24),
                  // Date header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: t.tint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            date,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${dayRecords.length} dispensed',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Records for this date
                  ...dayRecords.map((record) {
                    final prescription =
                        record['prescription'] as Map<String, dynamic>?;
                    final patient = record['patient'] as Map<String, dynamic>?;
                    final profile =
                        patient?['profiles'] as Map<String, dynamic>?;
                    final items =
                        prescription?['prescription_items'] as List? ?? [];
                    final dispensedAt = DateTime.parse(
                      record['dispensed_at'] as String,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SquircleCard(
                        radius: AppSpacing.squircleGrouped,
                        borderSide: BorderSide(color: t.divider),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Patient info
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: t.tint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Iconsax.user,
                                    color: t.accent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile?['full_name'] as String? ??
                                            'Unknown',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: t.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        timeFormat.format(dispensedAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: t.textSecondary,
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
                                    Icons.check_rounded,
                                    color: t.accent,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            // Diagnosis
                            if (prescription?['diagnosis'] != null) ...[
                              const SizedBox(height: 12),
                              Divider(height: 1, color: t.divider),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Iconsax.health,
                                    size: 18,
                                    color: t.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      prescription!['diagnosis'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // Items dispensed
                            if (items.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children:
                                    items.map<Widget>((item) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: t.tint,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${item['medicine_name']} ${item['dosage']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: t.accent,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                            // Notes
                            if (record['notes'] != null &&
                                (record['notes'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Note: ${record['notes']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.box, size: 80, color: t.textSecondary),
            const SizedBox(height: 24),
            Text(
              'No Dispensing History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Medications you dispense will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
