import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../../../services/supabase_service.dart';
import '../../../../routing/screen_titles.dart';

class PatientNewPrescriptionScreen extends ConsumerStatefulWidget {
  const PatientNewPrescriptionScreen({super.key});

  @override
  ConsumerState<PatientNewPrescriptionScreen> createState() =>
      _PatientNewPrescriptionScreenState();
}

class _PatientNewPrescriptionScreenState
    extends ConsumerState<PatientNewPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;

  final List<_MedicationEntry> _medications = [];

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    for (final med in _medications) {
      med.dispose();
    }
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.tokens.accent),
    );
  }

  void _addMedication() {
    setState(() {
      _medications.add(_MedicationEntry());
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications[index].dispose();
      _medications.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_medications.isEmpty) {
      _snack('Please add at least one medication');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patient = await ref.read(patientDataProvider.future);
      if (patient == null) {
        throw Exception('Patient profile not found');
      }

      await SupabaseService.instance.createPrescription(
        patientId: patient.id,
        diagnosis: _diagnosisController.text.trim(),
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
        isPublic: _isPublic,
        patientEntered: true,
        items: _medications.map((med) => med.toJson()).toList(),
      );

      // Refresh cached data
      ref.invalidate(patientPrescriptionsProvider);

      if (mounted) {
        _snack('Prescription saved as patient input');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = ref.watch(currentProfileProvider);
    final patient = ref.watch(patientDataProvider);

    return CSScaffold(
      title: ScreenTitles.patientAddPrescription,
      body: patient.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data:
            (_) => Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  // Info banner
                  SquircleCard(
                    radius: AppSpacing.squircleGrouped,
                    color: t.tint,
                    borderSide: BorderSide(
                      color: t.accent.withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Iconsax.info_circle, color: t.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Prescriptions you add here are marked as patient input. '
                            'Clinicians will see this flag.',
                            style: TextStyle(color: t.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Patient name
                  profile.when(
                    data:
                        (p) =>
                            p != null
                                ? SquircleCard(
                                  radius: AppSpacing.squircleGrouped,
                                  color: t.tint,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Iconsax.user, color: t.accent),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.fullName.isNotEmpty
                                                  ? p.fullName
                                                  : 'You',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: t.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Patient',
                                              style: TextStyle(
                                                color: t.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 20),
                  // Diagnosis
                  _label('Diagnosis'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _diagnosisController,
                    decoration: const InputDecoration(
                      hintText: 'Enter diagnosis',
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a diagnosis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Notes
                  _label('Notes (optional)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Additional notes',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  // Medications
                  Row(
                    children: [
                      Text(
                        'Medications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addMedication,
                        icon: const Icon(Iconsax.add, size: 20),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_medications.isEmpty)
                    SquircleCard(
                      radius: AppSpacing.squircleGrouped,
                      borderSide: BorderSide(color: t.divider),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Iconsax.health,
                            size: 40,
                            color: t.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No medications added',
                            style: TextStyle(color: t.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(_medications.length, (index) {
                      return _buildMedicationCard(index);
                    }),
                  const SizedBox(height: 24),
                  // Public toggle
                  SquircleCard(
                    radius: AppSpacing.squircleGrouped,
                    borderSide: BorderSide(color: t.divider),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _isPublic ? Iconsax.global : Iconsax.lock_1,
                          color: _isPublic ? t.accent : t.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Make Public',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary,
                                ),
                              ),
                              Text(
                                'Visible to first responders via QR',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isPublic,
                          onChanged:
                              (value) => setState(() => _isPublic = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Submit button
                  CSPrimaryButton(
                    label: 'Save Prescription',
                    loading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: context.tokens.textPrimary,
    ),
  );

  Widget _buildMedicationCard(int index) {
    final t = context.tokens;
    final med = _medications[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(color: t.divider),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: t.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Medication',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: t.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeMedication(index),
                  icon: const Icon(Iconsax.close_circle, size: 20),
                  style: IconButton.styleFrom(foregroundColor: t.error),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: med.nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name',
                hintText: 'e.g., Paracetamol',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: med.dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'e.g., 500mg',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: med.frequencyController,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      hintText: 'e.g., Twice daily',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: med.durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      hintText: 'e.g., 7 days',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: med.quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'e.g., 14',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: med.instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'e.g., Take after meals',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationEntry {
  final nameController = TextEditingController();
  final dosageController = TextEditingController();
  final frequencyController = TextEditingController();
  final durationController = TextEditingController();
  final quantityController = TextEditingController();
  final instructionsController = TextEditingController();

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    quantityController.dispose();
    instructionsController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': nameController.text.trim(),
      'dosage': dosageController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'duration':
          durationController.text.trim().isNotEmpty
              ? durationController.text.trim()
              : null,
      'quantity':
          quantityController.text.trim().isNotEmpty
              ? int.tryParse(quantityController.text.trim())
              : null,
      'instructions':
          instructionsController.text.trim().isNotEmpty
              ? instructionsController.text.trim()
              : null,
    };
  }
}
