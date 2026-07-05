import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Health History',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF121212)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF121212)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
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
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Iconsax.activity, size: 40, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No Health Records',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF121212),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No vital records logged yet under this category.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: vitals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final vital = vitals[index];
                    return _VitalRecordCard(vital: vital);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
              error: (err, stack) => Center(child: Text('Error: $err', style: GoogleFonts.plusJakartaSans())),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedTypeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTypeFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5200) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF5200) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
            content: Text('Decryption failed: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(widget.vital.recordedAt);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5200).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIcon(widget.vital.type),
              color: const Color(0xFFFF5200),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(widget.vital.type),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF121212),
                  ),
                )
              else if (_isDecrypting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Color(0xFFFF5200), strokeWidth: 2),
                )
              else
                OutlinedButton.icon(
                  onPressed: _decrypt,
                  icon: const Icon(Iconsax.lock_1, size: 12),
                  label: Text('Unlock', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5200),
                    side: const BorderSide(color: Color(0xFFFFE2D5)),
                    backgroundColor: const Color(0xFFFFF4F0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      case 'blood_pressure': return Iconsax.heart;
      case 'glucose': return Iconsax.drop;
      case 'weight': return Iconsax.weight;
      case 'heart_rate': return Iconsax.activity;
      default: return Iconsax.activity;
    }
  }

  String _getDisplayName(String type) {
    return type.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }
}
