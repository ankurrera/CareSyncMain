import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/audit_service.dart';
import '../../../../services/pdf_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../shared/models/user_profile.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/doctor_patient_provider.dart';
import '../../../patient/models/prescription.dart';
import '../../../patient/models/patient_data.dart';

// Imports for parity
import '../../../patient/models/prescription_input_models.dart';

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

  /// Fetch all master data
  Future<void> _loadMasterData() async {
    await Future.wait([
      _fetchTableData('medical_tests', (data) => _availableTests = data),
      _fetchTableData('medical_diagnoses', (data) => _availableDiagnoses = data),
      _fetchMedicines(),
    ]);
  }

  Future<void> _fetchTableData(String tableName, Function(List<String>) onSuccess) async {
    try {
      final response = await SupabaseService.instance.client
          .from(tableName)
          .select('name')
          .order('name')
          .limit(1000);

      if (mounted) {
        setState(() {
          onSuccess(List<String>.from(response.map((e) => e['name'] as String)));
        });
      }
    } catch (e) {
      debugPrint('Error fetching $tableName: $e');
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
      debugPrint('Error fetching medicines: $e');
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isValidUntil ? _validUntil : _prescriptionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.doctor,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
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
    
    // Get entered drugs
    final enteredDrugs = _medications
        .map((m) => m.nameController.text.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toList();
        
    if (enteredDrugs.isEmpty) return alerts;

    // 1. Check Allergy Clashes
    final allergies = conditions
        .where((c) => c.conditionType.toLowerCase() == 'allergy')
        .toList();
        
    for (final drug in enteredDrugs) {
      for (final allergy in allergies) {
        final allergyText = allergy.description.toLowerCase();
        // Check if the allergy description matches the drug name
        if (allergyText.contains(drug) || drug.contains(allergyText) ||
            (allergyText.contains('penicillin') && drug.contains('penicil')) ||
            (allergyText.contains('aspirin') && drug.contains('aspirin'))) {
          alerts.add(_SafetyAlert(
            title: 'Drug-Allergy Clash Detected',
            message: 'Patient is registered as allergic to "${allergy.description}". Prescribing "$drug" is contraindicated.',
            isDestructive: true,
          ));
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
          isValid = false; // Expired
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
        'message': 'Co-administration increases the risk of serious bleeding events.',
        'severe': true,
      },
      {
        'drugs': ['ibuprofen', 'aspirin'],
        'message': 'Concomitant NSAID use increases the risk of gastrointestinal ulcers.',
        'severe': false,
      },
      {
        'drugs': ['sildenafil', 'nitroglycerin'],
        'message': 'Severe hypotensive interaction. Do not prescribe together.',
        'severe': true,
      },
      {
        'drugs': ['simvastatin', 'amiodarone'],
        'message': 'Amiodarone increases simvastatin exposure, risking severe myopathy.',
        'severe': false,
      },
      {
        'drugs': ['clopidogrel', 'omeprazole'],
        'message': 'Omeprazole reduces the antiplatelet effectiveness of clopidogrel.',
        'severe': false,
      },
    ];

    for (final drug in enteredDrugs) {
      for (final activeDrug in activeDrugs) {
        for (final pair in dangerousPairs) {
          final pairList = pair['drugs'] as List<String>;
          if (pairList.contains(drug) && pairList.contains(activeDrug)) {
            alerts.add(_SafetyAlert(
              title: 'Drug-to-Drug Interaction Alert',
              message: 'Potential clash between new drug "$drug" and active drug "$activeDrug". ${pair['message']}',
              isDestructive: pair['severe'] as bool,
            ));
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
        const SnackBar(
          content: Text('Please add at least one medication'),
          backgroundColor: AppColors.warning,
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
      final signatureBase64 = await SecureStorageService.instance.getDoctorSignature();
      final signatureHash = await SecureStorageService.instance.getDoctorSignatureHash();

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
        debugPrint('PDF Generation Failed: $e');
      }

      final doctorDetails = {
        'doctor_name': doctorProfile?.fullName ?? 'Dr. Unknown',
        'hospital_clinic_name': doctorProfile?.hospitalName ?? 'Private Practice',
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
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription Signed, PDF Generated & Issued'),
            backgroundColor: AppColors.doctor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
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
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: SizedBox(
              width: width,
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
    );
  }

  // Helper for standard list item padding
  Widget _buildStandardDropdownItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1E293B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentProfileProvider);
    final conditions = ref.watch(doctorPatientConditionsProvider(widget.patientId)).valueOrNull ?? [];
    final prescriptions = ref.watch(doctorPatientPrescriptionsProvider(widget.patientId)).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Write Prescription',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFF1F5F9), // Slate 100
            height: 1.0,
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

                    Text('Clinical Diagnosis'.toUpperCase(), style: _headerStyle),
                    const SizedBox(height: 8),
                    _buildDiagnosisField(), // Uses reusable builder
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rx Medications'.toUpperCase(), style: _headerStyle),
                        TextButton.icon(
                          onPressed: _addMedication,
                          icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF0284C7)),
                          label: Text(
                            'Add Drug',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_medications.isEmpty)
                      _buildEmptyState()
                    else
                      ...List.generate(_medications.length, (index) => _buildMedicationCard(index)),

                    // Safety Alerts Section (DDI & Allergy Checks)
                    (() {
                      final alerts = _getSafetyAlerts(conditions, prescriptions);
                      if (alerts.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: alerts.map((alert) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: alert.isDestructive ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB), // Rose 50 / Amber 50
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: alert.isDestructive ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A), // Rose 200 / Amber 200
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  alert.isDestructive ? Iconsax.danger : Iconsax.warning_2,
                                  color: alert.isDestructive ? const Color(0xFFE11D48) : const Color(0xFFD97706),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alert.title,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: alert.isDestructive ? const Color(0xFF9F1239) : const Color(0xFF92400E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        alert.message,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: alert.isDestructive ? const Color(0xFFBE123C) : const Color(0xFFB45309),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      );
                    })(),

                    const SizedBox(height: 32),

                    _buildSectionHeader('Recommended Tests (Optional)'),
                    const SizedBox(height: 12),
                    _buildTestsSection(), // Uses reusable builder

                    const SizedBox(height: 32),

                    _buildSectionHeader('Prescription Details'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: _cardDecoration,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildMetadataSection(),
                          const Divider(height: 32),
                          _buildSafetyFlags(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('Clinical Notes'.toUpperCase(), style: _headerStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: _inputDecoration(hint: 'Add instructions, observations or warnings...'),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 24),

                    Container(
                      decoration: _cardDecoration,
                      child: SwitchListTile.adaptive(
                        title: Text(
                          'Emergency Access',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          'Allow first responders to view via QR code scan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeTrackColor: const Color(0xFF0284C7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ]
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: _isLoading
                ? null
                : () {
              ref.read(currentProfileProvider).whenData((profile) {
                _submit(profile);
              });
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7), // Premium Clinical Blue
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'Sign & Issue Prescription',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // --- STYLES & DECORATIONS ---

  TextStyle get _headerStyle => GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF475569), // Slate 600
    letterSpacing: 0.8,
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.015),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  InputDecoration _inputDecoration({required String hint, String? label, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC), // Slate 50
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5), // Clinical blue focus
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LayoutBuilder to capture exact width
          LayoutBuilder(
              builder: (context, constraints) {
                return Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') return const Iterable<String>.empty();
                    return _availableTests.where((String option) {
                      final matchesQuery = option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      final isNotAlreadySelected = !_selectedTests.contains(option);
                      return matchesQuery && isNotAlreadySelected;
                    });
                  },
                  displayStringForOption: (option) => '', // Keep field clear after select
                  onSelected: (String selection) {
                    _addTest(selection);
                  },
                  // Reusable Custom Builder
                  optionsViewBuilder: (context, onSelected, options) {
                    return _customOptionsViewBuilder(
                      context,
                      onSelected,
                      options,
                      constraints.maxWidth,
                          (option) => _buildStandardDropdownItem(option), // Standard look
                    );
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
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
                          icon: const Icon(Icons.add_circle, color: AppColors.doctor),
                          onPressed: () {
                            _addTest(controller.text);
                            controller.clear();
                          },
                        ),
                      ),
                    );
                  },
                );
              }
          ),
          if (_selectedTests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTests.map((test) {
                return Chip(
                  label: Text(test, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  backgroundColor: AppColors.doctor.withValues(alpha: 0.05),
                  side: BorderSide(color: AppColors.doctor.withValues(alpha: 0.2)),
                  deleteIcon: const Icon(Icons.close, size: 16, color: AppColors.doctor),
                  onDeleted: () => _removeTest(test),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                widget.patientName.isNotEmpty ? widget.patientName[0].toUpperCase() : 'P',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patientName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A), // Slate 900
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'ID: ${widget.patientId.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Patient',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisField() {
    return LayoutBuilder(
        builder: (context, constraints) {
          return Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') return const Iterable<String>.empty();
              return _availableDiagnoses.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              _diagnosisController.text = selection;
            },
            // Reusable Custom Builder
            optionsViewBuilder: (context, onSelected, options) {
              return _customOptionsViewBuilder(
                context,
                onSelected,
                options,
                constraints.maxWidth,
                    (option) => _buildStandardDropdownItem(option), // Standard look
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              controller.addListener(() {
                _diagnosisController.text = controller.text;
              });
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                decoration: _inputDecoration(
                  hint: 'Search ICD-10 or common diagnosis...',
                  suffix: const Icon(Iconsax.search_normal_1, color: Color(0xFF64748B), size: 18),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Diagnosis required' : null,
              );
            },
          );
        }
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Iconsax.document_text_1, size: 32, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Medications Added Yet',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "+ Add Drug" to append items to this prescription.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
                  () => _selectDate(context, false)
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

  Widget _buildDateInput(String label, DateTime date, VoidCallback onTap, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isAlert ? AppColors.warning.withValues(alpha: 0.5) : Colors.grey.shade200
              ),
            ),
            child: Row(
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyFlags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Safety Checks", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        _buildSafetyCheckTile('Allergies checked?', _allergiesMentioned, (v) => setState(() => _allergiesMentioned = v)),
        const SizedBox(height: 8),
        _buildSafetyCheckTile('Pregnancy/Lactation check?', _pregnancyBreastfeeding, (v) => setState(() => _pregnancyBreastfeeding = v)),
      ],
    );
  }

  Widget _buildSafetyCheckTile(String title, bool? value, Function(bool?) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155), // Slate 700
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Slate 100
            borderRadius: BorderRadius.circular(8),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(int index) {
    final med = _medications[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Drug #${index + 1}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _removeMedication(index),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFF1F5F9), height: 1.0),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // MEDICINE SEARCH AUTOCOMPLETE (UPDATED)
                LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue val) {
                          if (val.text == '') return const Iterable<Map<String, dynamic>>.empty();
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
                        // Reusable Custom Builder with Custom Item
                        optionsViewBuilder: (context, onSelected, options) {
                          return _customOptionsViewBuilder(
                            context,
                            onSelected,
                            options,
                            constraints.maxWidth,
                                (option) {
                              // Custom item for medicine (with subtitle)
                              final name = option['name'];
                              final dosage = option['dosage'] ?? '';
                              final type = option['type'] ?? '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    if(dosage.isNotEmpty || type.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '$dosage • $type',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFF64748B),
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
                                label: 'Medicine Name'
                            ),
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          );
                        },
                      );
                    }
                ),
                const SizedBox(height: 12),

                // Grid for Type, Dose, Freq
                Row(
                  children: [
                    // New Type Field
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.typeController,
                        decoration: _inputDecoration(hint: 'Tab/Inj', label: 'Type'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: med.dosageController,
                        decoration: _inputDecoration(hint: '500mg', label: 'Dose'),
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
                        decoration: _inputDecoration(hint: '5 days', label: 'Duration'),
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
    return InkWell(
      onTap: () {
        if (label.contains('-')) {
          med.frequencyController.text = label;
        } else {
          med.instructionsController.text = label;
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9), // Slate 100
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: const Color(0xFF475569), // Slate 600
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _MedicationEntry {
  final nameController = TextEditingController();
  final typeController = TextEditingController(); // ADDED
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
      'medicine_type': typeController.text.trim(), // Added to JSON
      'dosage': dosageController.text.trim(),
      'frequency': frequencyController.text.trim(),
      'duration': durationController.text.trim().isNotEmpty
          ? durationController.text.trim()
          : null,
      'quantity': quantityController.text.trim().isNotEmpty
          ? int.tryParse(quantityController.text.trim())
          : null,
      'instructions': instructionsController.text.trim().isNotEmpty
          ? instructionsController.text.trim()
          : null,
    };
  }
}

class _SafetyAlert {
  final String title;
  final String message;
  final bool isDestructive; // true for red (severe), false for amber (warning)
  
  _SafetyAlert({
    required this.title,
    required this.message,
    required this.isDestructive,
  });
}