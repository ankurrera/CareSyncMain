import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/vital.dart';
import '../../providers/vitals_provider.dart';
import '../../../../services/encryption_service.dart';

class VitalsHistoryScreen extends ConsumerStatefulWidget {
  const VitalsHistoryScreen({super.key});

  @override
  ConsumerState<VitalsHistoryScreen> createState() => _VitalsHistoryScreenState();
}

class _VitalsHistoryScreenState extends ConsumerState<VitalsHistoryScreen> {
  String _selectedTypeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final vitalsAsync = ref.watch(filteredVitalsProvider(_selectedTypeFilter));

    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        title: const Text('Health History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                  return const Center(child: Text('No health records found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: vitals.length,
                  itemBuilder: (context, index) {
                    final vital = vitals[index];
                    return _VitalRecordCard(vital: vital);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedTypeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedTypeFilter = value);
      },
      selectedColor: AppColors.softPrimary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.softPrimary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.softPrimary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
          SnackBar(content: Text('Decryption failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(widget.vital.recordedAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.softPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIcon(widget.vital.type),
              color: AppColors.softPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(widget.vital.type),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_decryptedValue != null)
                Text(
                  '$_decryptedValue ${widget.vital.unit}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.textMain,
                  ),
                )
              else if (_isDecrypting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: _decrypt,
                  icon: const Icon(Icons.lock_outline_rounded, size: 14),
                  label: const Text('Unlock'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.softPrimary,
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
      case 'blood_pressure': return Icons.water_drop_rounded;
      case 'glucose': return Icons.opacity_rounded;
      case 'weight': return Icons.monitor_weight_rounded;
      case 'heart_rate': return Icons.favorite_rounded;
      default: return Icons.analytics_rounded;
    }
  }

  String _getDisplayName(String type) {
    return type.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
