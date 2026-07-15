import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/vital.dart';
import '../../providers/vitals_provider.dart';
import '../../../../routing/screen_titles.dart';
import '../../../../services/encryption_service.dart';

class VitalsHistoryScreen extends ConsumerStatefulWidget {
  const VitalsHistoryScreen({super.key});

  @override
  ConsumerState<VitalsHistoryScreen> createState() =>
      _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends ConsumerState<VitalsHistoryScreen> {
  String _selectedTypeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final vitalsAsync = ref.watch(filteredVitalsProvider(_selectedTypeFilter));

    return CSScaffold(
      title: ScreenTitles.patientVitalsHistory,
      body: Column(
        children: [
          // Segmented Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                ...VitalType.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildFilterChip(
                      type.name.replaceAll(' ', '_').toLowerCase(),
                      type.name,
                    ),
                  );
                }),
              ],
            ),
          ),

          Expanded(
            child: vitalsAsync.when(
              data: (vitals) {
                if (vitals.isEmpty) {
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
                              Iconsax.activity,
                              size: 40,
                              color: t.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No Health Records',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No vital records logged yet under this category.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: vitals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vital = vitals[index];
                    return _VitalRecordCard(vital: vital);
                  },
                );
              },
              loading:
                  () =>
                      Center(child: CircularProgressIndicator(color: t.accent)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final t = context.tokens;
    final isSelected = _selectedTypeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTypeFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? t.accent : t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? t.accent : t.divider,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? t.accentOn : t.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _VitalRecordCard extends StatefulWidget {
  final Vital vital;
  const _VitalRecordCard({required this.vital});

  @override
  State<_VitalRecordCard> createState() => _VitalRecordCardState();
}

class _VitalRecordCardState extends State<_VitalRecordCard> {
  String? _decryptedValue;
  bool _isDecrypting = false;

  Future<void> _decrypt() async {
    setState(() => _isDecrypting = true);
    try {
      final decrypted = await EncryptionService.instance.decryptMedicalRecord(
        encryptedData: widget.vital.value,
        patientId: widget.vital.patientId,
        biometricReason: 'Authenticate to view this health record',
      );
      setState(() {
        _decryptedValue = decrypted;
        _isDecrypting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isDecrypting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Decryption failed: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dateStr = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(widget.vital.recordedAt);

    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
            child: Icon(_getIcon(widget.vital.type), color: t.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(widget.vital.type),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_decryptedValue != null)
                Text(
                  '$_decryptedValue ${widget.vital.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: t.textPrimary,
                  ),
                )
              else if (_isDecrypting)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: t.accent,
                    strokeWidth: 2,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _decrypt,
                  icon: const Icon(Iconsax.lock_1, size: 12),
                  label: const Text(
                    'Unlock',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.accent,
                    side: BorderSide(color: t.accent.withValues(alpha: 0.4)),
                    backgroundColor: t.tint,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'blood_pressure':
        return Iconsax.heart;
      case 'glucose':
        return Iconsax.drop;
      case 'weight':
        return Iconsax.weight;
      case 'heart_rate':
        return Iconsax.activity;
      default:
        return Iconsax.activity;
    }
  }

  String _getDisplayName(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
