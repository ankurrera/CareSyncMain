import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../models/patient_data.dart';
import '../../providers/patient_provider.dart';
import 'prescriptions_screen.dart'; // To reuse PrescriptionCard

class MedicalHistoryScreen extends ConsumerStatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  ConsumerState<MedicalHistoryScreen> createState() =>
      _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends ConsumerState<MedicalHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conditionsAsync = ref.watch(medicalConditionsProvider);
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Medical Records',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF121212),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: const Color(0xFF121212),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Prescriptions'),
                Tab(text: 'Medical History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Prescriptions ─────────────────────────────────────────
          prescriptionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5200)),
            ),
            error: (error, _) => _buildErrorState('prescriptions'),
            data: (prescriptions) {
              if (prescriptions.isEmpty) {
                return _buildEmptyPrescriptionsState(context);
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(patientPrescriptionsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: prescriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => PrescriptionCard(
                      prescription: prescriptions[index]),
                ),
              );
            },
          ),

          // ── Tab 2: Medical History ───────────────────────────────────────
          conditionsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5200)),
            ),
            error: (error, _) {
              if (error is KYCRequiredException) {
                return _buildKycRequiredState(context);
              }
              return _buildErrorState('conditions');
            },
            data: (conditions) {
              if (conditions.isEmpty) {
                return _buildEmptyConditionsState(context);
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(medicalConditionsProvider),
                child: ListView.builder(
                  padding: AppSpacing.screenPadding,
                  itemCount: conditions.length,
                  itemBuilder: (context, index) {
                    final condition = conditions[index];
                    return _buildConditionCard(context, condition);
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: _tabController.index == 0
            ? FloatingActionButton.extended(
                heroTag: 'add_prescription_btn',
                onPressed: () =>
                    context.push(RouteNames.patientAddPrescription),
                backgroundColor: const Color(0xFF121212),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                icon: const Icon(Iconsax.add, size: 20),
                label: Text('Add Rx',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold)),
              )
            : FloatingActionButton.extended(
                heroTag: 'add_condition_btn',
                onPressed: () => _showAddConditionDialog(context),
                backgroundColor: const Color(0xFF121212),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                icon: const Icon(Iconsax.add, size: 20),
                label: Text('Add Condition',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }

  Widget _buildEmptyPrescriptionsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: const Icon(Iconsax.document_text,
                  size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Prescriptions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121212),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add prescriptions to easily track your medications.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConditionsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: const Icon(Iconsax.activity,
                  size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Chronic Conditions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121212),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Log chronic conditions, illnesses or allergies for your emergency pass.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycRequiredState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Iconsax.shield_security,
              size: 72,
              color: Color(0xFFFF5200),
            ),
            const SizedBox(height: 20),
            Text(
              'KYC Verification Required',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121212),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to verify your identity to view or manage medical records.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.kycVerification),
              icon: const Icon(Iconsax.verify, size: 18),
              label: const Text('Verify Identity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121212),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.close_circle, size: 44, color: Color(0xFFEF4444)),
          const SizedBox(height: 16),
          Text(
            'Failed to load $type data',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              if (type == 'prescriptions') {
                ref.invalidate(patientPrescriptionsProvider);
              } else {
                ref.invalidate(medicalConditionsProvider);
              }
            },
            child: Text(
              'Retry',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFFF5200),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCard(BuildContext context, MedicalCondition condition) {
    final type = condition.conditionType;
    final severity = condition.severity;
    final isPublic = condition.isPublic;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.012),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getTypeColor(type).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatType(type),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _getTypeColor(type),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (severity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getSeverityColor(severity).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _getSeverityColor(severity),
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  isPublic ? Iconsax.eye : Iconsax.eye_slash,
                  size: 16,
                  color: isPublic
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              condition.description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPublic ? Iconsax.global : Iconsax.security_user,
                  size: 14,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  isPublic ? 'Visible on emergency pass' : 'Private (locked)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _deleteCondition(context, condition.id),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      Iconsax.trash,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'allergy':
        return const Color(0xFFEF4444);
      case 'chronic':
        return Colors.orange;
      case 'medication':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatType(String type) {
    switch (type) {
      case 'allergy':
        return 'ALLERGY';
      case 'chronic':
        return 'CHRONIC';
      case 'medication':
        return 'MEDICATION';
      default:
        return 'OTHER';
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
      case 'severe':
        return const Color(0xFFEF4444);
      case 'moderate':
        return Colors.orange;
      default:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _deleteCondition(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Record',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove this medical record?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Delete', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('medical_conditions')
            .delete()
            .eq('id', id);

        ref.invalidate(medicalConditionsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record deleted successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting record: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddConditionDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    String selectedType = 'allergy';
    String selectedSeverity = 'moderate';
    bool isPublic = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Add Medical Record',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Type',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'allergy', child: Text('Allergy')),
                    DropdownMenuItem(
                        value: 'chronic', child: Text('Chronic Condition')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Severity',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedSeverity,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mild', child: Text('Mild')),
                    DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                    DropdownMenuItem(value: 'severe', child: Text('Severe')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => selectedSeverity = val);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Penicillin allergy, Type 2 Diabetes',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: isPublic,
                      activeColor: const Color(0xFFFF5200),
                      onChanged: (val) {
                        if (val != null) setState(() => isPublic = val);
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Show on Emergency Pass',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.plusJakartaSans()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (descriptionController.text.trim().isEmpty) return;

                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId == null) return;

                  final patient = await Supabase.instance.client
                      .from('patients')
                      .select('id')
                      .eq('user_id', userId)
                      .single();

                  final patientId = patient['id'] as String;

                  await Supabase.instance.client
                      .from('medical_conditions')
                      .insert({
                    'patient_id': patientId,
                    'condition_type': selectedType,
                    'severity': selectedSeverity,
                    'description': descriptionController.text.trim(),
                    'is_public': isPublic,
                  });

                  ref.invalidate(medicalConditionsProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Record added successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding record: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121212),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
