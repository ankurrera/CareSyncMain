import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/logging/app_logger.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/circular_icon_button.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/audit_service.dart';
import '../../../../services/pdf_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../shared/models/user_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/doctor_patient_provider.dart';
import '../../../patient/models/prescription.dart';
import '../../../../routing/screen_titles.dart';
import '../../../patient/models/patient_data.dart';

// Imports for parity
import '../../../patient/models/prescription_input_models.dart';
import 'prescription_history_screen.dart';

class NewPrescriptionScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const NewPrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<NewPrescriptionScreen> createState() =>
      _NewPrescriptionScreenState();
}

class _NewPrescriptionScreenState extends ConsumerState<NewPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _testController = TextEditingController();

  bool _isPublic = false;
  bool _isLoading = false;

  // Metadata Fields
  DateTime _prescriptionDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  final PrescriptionType _prescriptionType = PrescriptionType.newPrescription;

  // Safety Flags
  bool? _allergiesMentioned;
  bool? _pregnancyBreastfeeding;
  bool? _chronicConditionLinked;

  final List<_MedicationEntry> _medications = [];
  final List<String> _selectedTests = [];

  // DYNAMIC DATA
  List<String> _availableTests = [];
  List<String> _availableDiagnoses = [];
  List<Map<String, dynamic>> _availableMedicines = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _testController.dispose();
    for (final med in _medications) {
      med.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    await Future.wait([
      _fetchTableData('medical_tests', (data) => _availableTests = data),
      _fetchTableData(
        'medical_diagnoses',
        (data) => _availableDiagnoses = data,
      ),
      _fetchMedicines(),
    ]);
  }

  Future<void> _fetchTableData(
    String tableName,
    Function(List<String>) onSuccess,
  ) async {
    try {
      final response = await SupabaseService.instance.client
          .from(tableName)
          .select('name')
          .order('name')
          .limit(1000);

      if (mounted) {
        setState(() {
          onSuccess(
            List<String>.from(response.map((e) => e['name'] as String)),
          );
        });
      }
    } catch (e) {
      AppLogger.warning(
        'Error fetching $tableName',
        category: LogCategory.database,
        error: e,
      );
    }
  }

  Future<void> _fetchMedicines() async {
    try {
      final response = await SupabaseService.instance.client
          .from('medicines')
          .select('name, dosage, type')
          .limit(1000);

      if (mounted) {
        setState(() {
          _availableMedicines = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      AppLogger.warning(
        'Error fetching medicines',
        category: LogCategory.database,
        error: e,
      );
    }
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

  void _addTest(String testName) {
    if (testName.trim().isEmpty) return;
    if (!_selectedTests.contains(testName)) {
      setState(() {
        _selectedTests.add(testName);
      });
    }
  }

  void _removeTest(String testName) {
    setState(() {
      _selectedTests.remove(testName);
    });
  }

  Future<void> _selectDate(BuildContext context, bool isValidUntil) async {
    final t = context.tokens;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isValidUntil ? _validUntil : _prescriptionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: t.accent, onPrimary: t.accentOn),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isValidUntil) {
          _validUntil = picked;
        } else {
          _prescriptionDate = picked;
          if (_validUntil.isBefore(_prescriptionDate)) {
            _validUntil = _prescriptionDate.add(const Duration(days: 30));
          }
        }
      });
    }
  }

  List<_SafetyAlert> _getSafetyAlerts(
    List<MedicalCondition> conditions,
    List<Prescription> prescriptions,
  ) {
    final alerts = <_SafetyAlert>[];

    final enteredDrugs =
        _medications
            .map((m) => m.nameController.text.trim().toLowerCase())
            .where((name) => name.isNotEmpty)
            .toList();

    if (enteredDrugs.isEmpty) return alerts;

    // 1. Check Allergy Clashes
    final allergies =
        conditions
            .where((c) => c.conditionType.toLowerCase() == 'allergy')
            .toList();

    for (final drug in enteredDrugs) {
      for (final allergy in allergies) {
        final allergyText = allergy.description.toLowerCase();
        if (allergyText.contains(drug) ||
            drug.contains(allergyText) ||
            (allergyText.contains('penicillin') && drug.contains('penicil')) ||
            (allergyText.contains('aspirin') && drug.contains('aspirin'))) {
          alerts.add(
            _SafetyAlert(
              title: 'Drug-Allergy Clash Detected',
              message:
                  'Patient is registered as allergic to "${allergy.description}". Prescribing "$drug" is contraindicated.',
              isDestructive: true,
            ),
          );
        }
      }
    }

    // 2. Check Drug-to-Drug Interactions (DDI)
    final activeDrugs = <String>[];
    for (final p in prescriptions) {
      final validUntil = p.metadata?['valid_until'] as String?;
      bool isValid = true;
      if (validUntil != null) {
        final date = DateTime.tryParse(validUntil);
        if (date != null && date.isBefore(DateTime.now())) {
          isValid = false;
        }
      }
      if (isValid) {
        for (final item in p.items) {
          final name = item.medicineName.toLowerCase();
          if (name.isNotEmpty) {
            activeDrugs.add(name);
          }
        }
      }
    }

    final dangerousPairs = [
      {
        'drugs': ['aspirin', 'warfarin'],
        'message':
            'Co-administration increases the risk of serious bleeding events.',
        'severe': true,
      },
      {
        'drugs': ['ibuprofen', 'aspirin'],
        'message':
            'Concomitant NSAID use increases the risk of gastrointestinal ulcers.',
        'severe': false,
      },
      {
        'drugs': ['sildenafil', 'nitroglycerin'],
        'message': 'Severe hypotensive interaction. Do not prescribe together.',
        'severe': true,
      },
      {
        'drugs': ['simvastatin', 'amiodarone'],
        'message':
            'Amiodarone increases simvastatin exposure, risking severe myopathy.',
        'severe': false,
      },
      {
        'drugs': ['clopidogrel', 'omeprazole'],
        'message':
            'Omeprazole reduces the antiplatelet effectiveness of clopidogrel.',
        'severe': false,
      },
    ];

    for (final drug in enteredDrugs) {
      for (final activeDrug in activeDrugs) {
        for (final pair in dangerousPairs) {
          final pairList = pair['drugs'] as List<String>;
          if (pairList.contains(drug) && pairList.contains(activeDrug)) {
            alerts.add(
              _SafetyAlert(
                title: 'Drug-to-Drug Interaction Alert',
                message:
                    'Potential clash between new drug "$drug" and active drug "$activeDrug". ${pair['message']}',
                isDestructive: pair['severe'] as bool,
              ),
            );
          }
        }
      }
    }

    return alerts;
  }

  Future<void> _submit(UserProfile? doctorProfile) async {
    if (!_formKey.currentState!.validate()) return;

    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please add at least one medication'),
          backgroundColor: context.tokens.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Biometric Guard
    final authenticated = await showBiometricAuthDialog(
      context: context,
      reason: 'Verify identity to sign prescription',
      allowBiometricOnly: false,
    );

    if (!authenticated) return;

    setState(() => _isLoading = true);

    try {
      final medicationList = _medications.map((med) => med.toJson()).toList();

      String? pdfUrl;
      final signatureBase64 =
          await SecureStorageService.instance.getDoctorSignature();
      final signatureHash =
          await SecureStorageService.instance.getDoctorSignatureHash();

      try {
        if (doctorProfile != null) {
          final pdfBytes = await PdfService.generatePrescription(
            doctor: doctorProfile,
            patientName: widget.patientName,
            patientId: widget.patientId,
            date: _prescriptionDate,
            diagnosis: _diagnosisController.text.trim(),
            notes: _notesController.text.trim(),
            medications: medicationList,
            tests: _selectedTests,
            signatureBase64: signatureBase64,
            signatureHash: signatureHash,
          );

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${widget.patientId}_$timestamp.pdf';

          pdfUrl = await SupabaseService.instance.uploadFile(
            bucket: 'prescriptions',
            path: fileName,
            fileBytes: pdfBytes,
            contentType: 'application/pdf',
          );
        }
      } catch (e) {
        AppLogger.warning(
          'PDF Generation Failed',
          category: LogCategory.general,
          error: e,
        );
      }

      final doctorDetails = {
        'doctor_name': doctorProfile?.fullName ?? 'Dr. Unknown',
        'hospital_clinic_name':
            doctorProfile?.hospitalName ?? 'Private Practice',
        'specialization': doctorProfile?.specialization ?? '',
        'medical_registration_number': doctorProfile?.medicalRegNumber ?? '',
        'signature_uploaded': signatureBase64 != null,
        'signature_hash': signatureHash,
      };

      final metadata = {
        'biometric_verified': true,
        'signed_at': DateTime.now().toIso8601String(),
        'prescription_date': _prescriptionDate.toIso8601String(),
        'valid_until': _validUntil.toIso8601String(),
        'type': _prescriptionType.name,
        'recommended_tests': _selectedTests,
        'doctor_details': doctorDetails,
        'safety_flags': {
          'allergies_mentioned': _allergiesMentioned,
          'pregnancy_breastfeeding': _pregnancyBreastfeeding,
          'chronic_condition_linked': _chronicConditionLinked,
        },
        'pdf_url': pdfUrl,
      };

      await SupabaseService.instance.createPrescription(
        patientId: widget.patientId,
        diagnosis: _diagnosisController.text.trim(),
        notes:
            _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
        isPublic: _isPublic,
        items: medicationList,
        metadata: metadata,
      );

      await AuditService.instance.logAction(
        action: AuditAction.createPrescription,
        resourceType: 'prescription',
        metadata: {
          'patient_id': widget.patientId,
          'doctor_name': doctorProfile?.fullName,
          'biometric_verified': true,
          'pdf_generated': pdfUrl != null,
        },
      );

      if (mounted) {
        ref.invalidate(doctorPatientPrescriptionsProvider(widget.patientId));
        ref.invalidate(doctorPrescriptionsProvider(widget.patientId));
        ref.invalidate(doctorPrescriptionsProvider(null));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Prescription Signed, PDF Generated & Issued'),
            backgroundColor: context.tokens.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
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

  // --- REUSABLE DROPDOWN BUILDER ---
  Widget _customOptionsViewBuilder<T extends Object>(
    BuildContext context,
    AutocompleteOnSelected<T> onSelected,
    Iterable<T> options,
    double width,
    Widget Function(T option) itemBuilder,
  ) {
    final t = context.tokens;
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: SizedBox(
              width: width,
              child: Material(
                type: MaterialType.transparency,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final T option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: itemBuilder(option),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardDropdownItem(String text) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: t.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final currentUserAsync = ref.watch(currentProfileProvider);
    final conditions =
        ref
            .watch(doctorPatientConditionsProvider(widget.patientId))
            .valueOrNull ??
        [];
    final prescriptions =
        ref
            .watch(doctorPatientPrescriptionsProvider(widget.patientId))
            .valueOrNull ??
        [];

    return CSScaffold(
      title: ScreenTitles.doctorNewPrescription,
      leading: CircularIconButton(
        icon: Iconsax.close_circle,
        onTap: () => context.pop(),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: t.card,
        child: SafeArea(
          child: CSPrimaryButton(
            label: 'Sign & Issue Prescription',
            loading: _isLoading,
            onPressed: () {
              final profile = ref.read(currentProfileProvider).valueOrNull;
              _submit(profile);
            },
          ),
        ),
      ),
      body: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (doctorProfile) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientInfoBar(),
                    const SizedBox(height: 24),

                    Text(
                      'Clinical Diagnosis'.toUpperCase(),
                      style: _headerStyle,
                    ),
                    const SizedBox(height: 8),
                    _buildDiagnosisField(),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rx Medications'.toUpperCase(),
                          style: _headerStyle,
                        ),
                        TextButton.icon(
                          onPressed: _addMedication,
                          icon: Icon(Iconsax.add, size: 16, color: t.accent),
                          label: Text(
                            'Add Drug',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: t.accent,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: t.tint,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_medications.isEmpty)
                      _buildEmptyState()
                    else
                      ...List.generate(
                        _medications.length,
                        (index) => _buildMedicationCard(index),
                      ),

                    // Safety Alerts Section (DDI & Allergy Checks)
                    (() {
                      final alerts = _getSafetyAlerts(
                        conditions,
                        prescriptions,
                      );
                      if (alerts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children:
                              alerts.map((alert) {
                                final c =
                                    alert.isDestructive ? t.error : t.accent;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: c.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        alert.isDestructive
                                            ? Iconsax.danger
                                            : Iconsax.warning_2,
                                        color: c,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              alert.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: c,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              alert.message,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: t.textPrimary,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      );
                    })(),

                    const SizedBox(height: 32),

                    _buildSectionHeader('Recommended Tests (Optional)'),
                    const SizedBox(height: 12),
                    _buildTestsSection(),

                    const SizedBox(height: 32),

                    _buildSectionHeader('Prescription Details'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: _cardDecoration,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildMetadataSection(),
                          Divider(height: 32, color: t.divider),
                          _buildSafetyFlags(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('Clinical Notes'.toUpperCase(), style: _headerStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: _inputDecoration(
                        hint: 'Add instructions, observations or warnings...',
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: _cardDecoration,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Access',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: t.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Allow first responders to view via QR code scan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Switch.adaptive(
                            value: _isPublic,
                            onChanged: (v) => setState(() => _isPublic = v),
                            activeThumbColor: t.accent,
                            activeTrackColor: t.accent.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- STYLES & DECORATIONS ---

  TextStyle get _headerStyle => context.tokens.monoSectionHeader.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: context.tokens.textSecondary,
    letterSpacing: 0.8,
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: context.tokens.card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: context.tokens.divider.withValues(alpha: 0.5),
      width: 1.0,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    String? label,
    Widget? suffix,
  }) {
    final t = context.tokens;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: t.textSecondary.withValues(alpha: 0.8),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: t.textSecondary.withValues(alpha: 0.5),
        fontSize: 13,
      ),
      filled: true,
      fillColor: t.scaffold,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffix,
      isDense: true,
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title) {
    return Text(title.toUpperCase(), style: _headerStyle);
  }

  Widget _buildTestsSection() {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _availableTests.where((String option) {
                    final matchesQuery = option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                    final isNotAlreadySelected =
                        !_selectedTests.contains(option);
                    return matchesQuery && isNotAlreadySelected;
                  });
                },
                displayStringForOption: (option) => '',
                onSelected: (String selection) {
                  _addTest(selection);
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return _customOptionsViewBuilder(
                    context,
                    onSelected,
                    options,
                    constraints.maxWidth,
                    (option) => _buildStandardDropdownItem(option),
                  );
                },
                fieldViewBuilder: (
                  context,
                  controller,
                  focusNode,
                  onEditingComplete,
                ) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onSubmitted: (value) {
                      _addTest(value);
                      controller.clear();
                      onEditingComplete();
                    },
                    decoration: _inputDecoration(
                      hint: 'Search or type test name...',
                      suffix: IconButton(
                        icon: Icon(Iconsax.add_circle, color: t.accent),
                        onPressed: () {
                          _addTest(controller.text);
                          controller.clear();
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_selectedTests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _selectedTests.map((test) {
                    return Chip(
                      label: Text(
                        test,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: t.accent,
                        ),
                      ),
                      backgroundColor: t.tint,
                      side: BorderSide(color: t.accent.withValues(alpha: 0.2)),
                      deleteIcon: Icon(Icons.close, size: 16, color: t.accent),
                      onDeleted: () => _removeTest(test),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientInfoBar() {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.divider.withValues(alpha: 0.5), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.tint,
              border: Border.all(
                color: t.accent.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                widget.patientName.isNotEmpty
                    ? widget.patientName[0].toUpperCase()
                    : 'P',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'RECORD ID • ${widget.patientId.substring(0, 8).toUpperCase()}',
                  style: TextStyle(
                    color: t.textSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisField() {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') {
              return const Iterable<String>.empty();
            }
            return _availableDiagnoses.where((String option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },
          onSelected: (String selection) {
            _diagnosisController.text = selection;
          },
          optionsViewBuilder: (context, onSelected, options) {
            return _customOptionsViewBuilder(
              context,
              onSelected,
              options,
              constraints.maxWidth,
              (option) => _buildStandardDropdownItem(option),
            );
          },
          fieldViewBuilder: (
            context,
            controller,
            focusNode,
            onEditingComplete,
          ) {
            controller.addListener(() {
              _diagnosisController.text = controller.text;
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              onEditingComplete: onEditingComplete,
              decoration: _inputDecoration(
                hint: 'Search ICD-10 or common diagnosis...',
                suffix: Icon(
                  Iconsax.search_normal_1,
                  color: t.textSecondary,
                  size: 18,
                ),
              ),
              validator:
                  (value) =>
                      value == null || value.isEmpty
                          ? 'Diagnosis required'
                          : null,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36.0),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.scaffold.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(color: t.divider.withValues(alpha: 0.5)),
            ),
            child: Icon(
              Iconsax.document_text_1,
              size: 24,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No Medications Added Yet',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "+ Add Drug" to append items to this prescription.',
            style: TextStyle(
              color: t.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Row(
      children: [
        Expanded(
          child: _buildDateInput(
            'Prescription Date',
            _prescriptionDate,
            () => _selectDate(context, false),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDateInput(
            'Valid Until',
            _validUntil,
            () => _selectDate(context, true),
            isAlert: _validUntil.difference(_prescriptionDate).inDays < 7,
          ),
        ),
      ],
    );
  }

  Widget _buildDateInput(
    String label,
    DateTime date,
    VoidCallback onTap, {
    bool isAlert = false,
  }) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: t.textSecondary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isAlert
                        ? t.error.withValues(alpha: 0.5)
                        : t.divider.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: t.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyFlags() {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Safety Checks",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSafetyCheckTile(
          'Allergies checked?',
          _allergiesMentioned,
          (v) => setState(() => _allergiesMentioned = v),
        ),
        const SizedBox(height: 8),
        _buildSafetyCheckTile(
          'Pregnancy/Lactation check?',
          _pregnancyBreastfeeding,
          (v) => setState(() => _pregnancyBreastfeeding = v),
        ),
      ],
    );
  }

  Widget _buildSafetyCheckTile(
    String title,
    bool? value,
    Function(bool?) onChanged,
  ) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: t.scaffold.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentBtn('Yes', value == true, () => onChanged(true)),
              _buildSegmentBtn('No', value == false, () => onChanged(false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentBtn(String label, bool isSelected, VoidCallback onTap) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? t.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? t.accentOn : t.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final t = context.tokens;
    final med = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'MEDICATION ENTRY #${index + 1}'.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: t.accent,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeMedication(index),
                  icon: Icon(
                    Iconsax.close_circle,
                    size: 16,
                    color: t.textSecondary,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          Divider(color: t.divider, height: 1.0),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // MEDICINE SEARCH AUTOCOMPLETE
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue val) {
                        if (val.text == '') {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        return _availableMedicines.where((med) {
                          final name = med['name'].toString().toLowerCase();
                          final search = val.text.toLowerCase();
                          return name.contains(search);
                        });
                      },
                      displayStringForOption: (med) => med['name'],
                      onSelected: (selection) {
                        med.nameController.text = selection['name'] ?? '';
                        med.dosageController.text = selection['dosage'] ?? '';
                        med.typeController.text = selection['type'] ?? '';
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return _customOptionsViewBuilder(
                          context,
                          onSelected,
                          options,
                          constraints.maxWidth,
                          (option) {
                            final name = option['name'];
                            final dosage = option['dosage'] ?? '';
                            final type = option['type'] ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: t.textPrimary,
                                    ),
                                  ),
                                  if (dosage.isNotEmpty || type.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '$dosage • $type',
                                        style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      fieldViewBuilder: (ctx, ctrl, focus, onComp) {
                        ctrl.addListener(() {
                          if (ctrl.text != med.nameController.text) {
                            med.nameController.text = ctrl.text;
                          }
                        });
                        return TextFormField(
                          controller: ctrl,
                          focusNode: focus,
                          decoration: _inputDecoration(
                            hint: 'Search Medicine (e.g. Paracetamol)',
                            label: 'Medicine Name',
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Grid for Type, Dose, Freq
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.typeController,
                        decoration: _inputDecoration(
                          hint: 'Tab/Inj',
                          label: 'Type',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.dosageController,
                        decoration: _inputDecoration(
                          hint: '500mg',
                          label: 'Dose',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.frequencyController,
                        decoration: _inputDecoration(hint: 'BD', label: 'Freq'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: med.durationController,
                        decoration: _inputDecoration(
                          hint: '5 days',
                          label: 'Duration',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: med.quantityController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: '10', label: 'Qty'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Quick chips for frequency
                SizedBox(
                  height: 28,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildMiniChip(med, '1-0-1'),
                      const SizedBox(width: 6),
                      _buildMiniChip(med, '1-1-1'),
                      const SizedBox(width: 6),
                      _buildMiniChip(med, 'Before Food'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(_MedicationEntry med, String label) {
    final t = context.tokens;
    final bool isSelected =
        label.contains('-')
            ? med.frequencyController.text.trim() == label.trim()
            : med.instructionsController.text.trim().toLowerCase() ==
                label.trim().toLowerCase();

    return GestureDetector(
      onTap: () {
        setState(() {
          if (label.contains('-')) {
            if (med.frequencyController.text.trim() == label.trim()) {
              med.frequencyController.clear();
            } else {
              med.frequencyController.text = label;
            }
          } else {
            final currentText =
                med.instructionsController.text.trim().toLowerCase();
            final targetText = label.trim().toLowerCase();
            if (currentText == targetText) {
              med.instructionsController.clear();
            } else {
              med.instructionsController.text = label;
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? t.accent : t.scaffold,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? t.accent : t.divider.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? t.accentOn : t.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MedicationEntry {
  final nameController = TextEditingController();
  final typeController = TextEditingController();
  final dosageController = TextEditingController();
  final frequencyController = TextEditingController();
  final durationController = TextEditingController();
  final quantityController = TextEditingController();
  final instructionsController = TextEditingController();

  void dispose() {
    nameController.dispose();
    typeController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    quantityController.dispose();
    instructionsController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': nameController.text.trim(),
      'medicine_type': typeController.text.trim(),
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

class _SafetyAlert {
  final String title;
  final String message;
  final bool isDestructive;

  _SafetyAlert({
    required this.title,
    required this.message,
    required this.isDestructive,
  });
}
