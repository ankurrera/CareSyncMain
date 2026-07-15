import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../models/patient_data.dart';
import '../../providers/patient_provider.dart';
import '../widgets/prescription_card.dart';
import '../../../../routing/screen_titles.dart';

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
    final t = context.tokens;
    final conditionsAsync = ref.watch(medicalConditionsProvider);
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);

    return CSScaffold(
      title: ScreenTitles.patientMedicalHistory,
      automaticBack: false,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child:
            _tabController.index == 0
                ? FloatingActionButton.extended(
                  heroTag: 'add_prescription_btn',
                  onPressed:
                      () => context.push(RouteNames.patientAddPrescription),
                  backgroundColor: t.accent,
                  foregroundColor: t.accentOn,
                  elevation: 0,
                  icon: const Icon(Iconsax.add, size: 20),
                  label: const Text(
                    'Add Rx',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
                : FloatingActionButton.extended(
                  heroTag: 'add_condition_btn',
                  onPressed: () => _showAddConditionSheet(context),
                  backgroundColor: t.accent,
                  foregroundColor: t.accentOn,
                  elevation: 0,
                  icon: const Icon(Iconsax.add, size: 20),
                  label: const Text(
                    'Add Condition',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
      ),
      body: Column(
        children: [
          // Segmented tab control
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: t.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: t.accentOn,
              unselectedLabelColor: t.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Prescriptions'),
                Tab(text: 'Medical History'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: Prescriptions ─────────────────────────────────────
                prescriptionsAsync.when(
                  loading:
                      () => Center(
                        child: CircularProgressIndicator(color: t.accent),
                      ),
                  error: (error, _) => _buildErrorState('prescriptions'),
                  data: (prescriptions) {
                    if (prescriptions.isEmpty) {
                      return _buildEmptyState(
                        icon: Iconsax.document_text,
                        title: 'No Prescriptions',
                        subtitle:
                            'Add prescriptions to easily track your medications.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh:
                          () async =>
                              ref.invalidate(patientPrescriptionsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: prescriptions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder:
                            (context, index) => PrescriptionCard(
                              prescription: prescriptions[index],
                            ),
                      ),
                    );
                  },
                ),

                // ── Tab 2: Medical History ───────────────────────────────────
                conditionsAsync.when(
                  loading:
                      () => Center(
                        child: CircularProgressIndicator(color: t.accent),
                      ),
                  error: (error, _) {
                    if (error is KYCRequiredException) {
                      return _buildKycRequiredState(context);
                    }
                    return _buildErrorState('conditions');
                  },
                  data: (conditions) {
                    if (conditions.isEmpty) {
                      return _buildEmptyState(
                        icon: Iconsax.activity,
                        title: 'No Chronic Conditions',
                        subtitle:
                            'Log chronic conditions, illnesses or allergies for your emergency pass.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh:
                          () async => ref.invalidate(medicalConditionsProvider),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              child: Icon(icon, size: 40, color: t.textSecondary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycRequiredState(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.shield_security, size: 72, color: t.accent),
            const SizedBox(height: 20),
            Text(
              'KYC Verification Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to verify your identity to view or manage medical records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            CSPrimaryButton(
              label: 'Verify Identity',
              icon: Iconsax.verify,
              fullWidth: false,
              onPressed: () => context.push(RouteNames.kycVerification),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String type) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.close_circle, size: 44, color: t.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load $type data',
            style: TextStyle(fontWeight: FontWeight.w700, color: t.textPrimary),
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
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionCard(BuildContext context, MedicalCondition condition) {
    final t = context.tokens;
    final type = condition.conditionType;
    final severity = condition.severity;
    final isPublic = condition.isPublic;
    final severityColor = _severityColor(context, severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(color: t.divider),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: t.tint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatType(type),
                    style: t.monoMeta.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (severity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: t.monoMeta.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: severityColor,
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  isPublic ? Iconsax.eye : Iconsax.eye_slash,
                  size: 16,
                  color: isPublic ? t.accent : t.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              condition.description,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: t.divider),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPublic ? Iconsax.global : Iconsax.security_user,
                  size: 14,
                  color: t.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isPublic ? 'Visible on emergency pass' : 'Private (locked)',
                  style: TextStyle(
                    fontSize: 11,
                    color: t.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _deleteCondition(context, condition.id),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Icon(Iconsax.trash, size: 16, color: t.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(BuildContext context, String? severity) {
    final t = context.tokens;
    switch (severity) {
      case 'critical':
      case 'severe':
        return t.error;
      case 'moderate':
        return t.accent;
      default:
        return t.textSecondary;
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

  Future<void> _deleteCondition(BuildContext context, String id) async {
    final confirmed = await showConfirmSheet(
      context,
      icon: Iconsax.trash,
      title: 'Delete Record',
      message: 'Are you sure you want to remove this medical record?',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (confirmed) {
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting record: $e')));
        }
      }
    }
  }

  Future<void> _showAddConditionSheet(BuildContext context) async {
    final descriptionController = TextEditingController();
    String selectedType = 'allergy';
    String selectedSeverity = 'moderate';
    bool isPublic = true;

    await showAppSheet<void>(
      context,
      builder:
          (sheetCtx) => StatefulBuilder(
            builder: (sheetCtx, setSheetState) {
              final t = sheetCtx.tokens;
              Widget label(String text) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: t.textPrimary,
                  ),
                ),
              );
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add Medical Record',
                        textAlign: TextAlign.center,
                        style: t.sheetTitle,
                      ),
                      const SizedBox(height: 20),
                      label('Record Type'),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        items: const [
                          DropdownMenuItem(
                            value: 'allergy',
                            child: Text('Allergy'),
                          ),
                          DropdownMenuItem(
                            value: 'chronic',
                            child: Text('Chronic Condition'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      label('Severity'),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSeverity,
                        items: const [
                          DropdownMenuItem(value: 'mild', child: Text('Mild')),
                          DropdownMenuItem(
                            value: 'moderate',
                            child: Text('Moderate'),
                          ),
                          DropdownMenuItem(
                            value: 'severe',
                            child: Text('Severe'),
                          ),
                          DropdownMenuItem(
                            value: 'critical',
                            child: Text('Critical'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => selectedSeverity = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      label('Description'),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Penicillin allergy, Type 2 Diabetes',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: isPublic,
                            activeColor: t.accent,
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() => isPublic = val);
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              'Show on Emergency Pass',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: t.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CSTwoButtonRow(
                        cancelLabel: 'Cancel',
                        confirmLabel: 'Save',
                        onCancel: () => Navigator.pop(sheetCtx),
                        onConfirm:
                            () => _saveCondition(
                              type: selectedType,
                              severity: selectedSeverity,
                              description: descriptionController.text.trim(),
                              isPublic: isPublic,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<void> _saveCondition({
    required String type,
    required String severity,
    required String description,
    required bool isPublic,
  }) async {
    if (description.isEmpty) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final patient =
          await Supabase.instance.client
              .from('patients')
              .select('id')
              .eq('user_id', userId)
              .single();

      final patientId = patient['id'] as String;

      await Supabase.instance.client.from('medical_conditions').insert({
        'patient_id': patientId,
        'condition_type': type,
        'severity': severity,
        'description': description,
        'is_public': isPublic,
      });

      ref.invalidate(medicalConditionsProvider);

      if (!mounted) return;
      // Dismiss the sheet (pushed on the root navigator) then confirm.
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record added successfully')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding record: $e')));
      }
    }
  }
}
