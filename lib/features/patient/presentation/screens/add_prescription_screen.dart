import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../features/shared/services/ocr_service.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../family/providers/family_provider.dart';
import '../../models/prescription_input_models.dart';
import '../../providers/patient_provider.dart';
import '../widgets/doctor_info_card_widget.dart';
import '../widgets/medication_card_widget.dart';
import '../widgets/prescription_upload_widget.dart';
import '../../../../services/supabase_service.dart';

/// Comprehensive Add Prescription screen for patient input
class AddPrescriptionScreen extends ConsumerStatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  ConsumerState<AddPrescriptionScreen> createState() =>
      _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends ConsumerState<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Prescription Metadata
  DateTime _prescriptionDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  PrescriptionType _prescriptionType = PrescriptionType.newPrescription;

  // Doctor Details
  DoctorDetails _doctorDetails = const DoctorDetails(
    doctorName: '',
    hospitalClinicName: '',
    medicalRegistrationNumber: '',
  );

  // Prescription Upload
  PrescriptionUpload _prescriptionUpload = const PrescriptionUpload();

  // Diagnosis & Notes
  final _diagnosisController = TextEditingController();
  final _doctorNotesController = TextEditingController();
  final _patientNotesController = TextEditingController();

  // Dynamic Data for Autocomplete
  List<String> _availableDiagnoses = [];

  // Medications
  final List<MedicationDetails> _medications = [];

  // Safety Flags
  bool? _allergiesMentioned;
  bool? _pregnancyBreastfeeding;
  bool? _chronicConditionLinked;

  // Declaration
  bool _declarationAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadDiagnoses();
  }

  Future<void> _loadDiagnoses() async {
    try {
      final response = await SupabaseService.instance.client
          .from('medical_diagnoses')
          .select('name')
          .order('name')
          .limit(1000);
      if (mounted) {
        setState(() {
          _availableDiagnoses = List<String>.from(response.map((e) => e['name'] as String));
        });
      }
    } catch (e) {
      debugPrint('Error loading diagnoses: $e');
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _doctorNotesController.dispose();
    _patientNotesController.dispose();
    super.dispose();
  }

  void _addMedication() {
    setState(() {
      _medications.add(
        MedicationDetails(
          medicineName: '',
          dosage: '',
          frequency: '',
          duration: '',
          quantity: 0,
        ),
      );
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
  }

  void _updateMedication(int index, MedicationDetails details) {
    setState(() {
      _medications[index] = details;
    });
  }

  Future<void> _showSourceSelectionSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: AppColors.primary),
                title: const Text('Upload PDF / File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image == null) return;
      
      _processFile(File(image.path));
    } catch (e) {
      debugPrint('Image Picker Error: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        _processFile(File(result.files.single.path!));
      }
    } catch (e) {
      debugPrint('File Picker Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Error picking file'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _processFile(File file) async {
      setState(() => _isLoading = true);

      try {
        // Process File (Image or PDF)
        final prescriptionData = await OcrService().processPrescriptionFile(file);
        
        setState(() {
          // 1. Doctor & Hospital Name
          if (prescriptionData.doctorName != null || prescriptionData.hospitalName != null) {
            _doctorDetails = _doctorDetails.copyWith(
                doctorName: prescriptionData.doctorName ?? _doctorDetails.doctorName,
                hospitalClinicName: prescriptionData.hospitalName ?? _doctorDetails.hospitalClinicName,
            );
          }
          
          // 2. Date
          if (prescriptionData.date != null) {
            _prescriptionDate = prescriptionData.date!;
             // Auto-adjust valid until if needed
            if (_validUntil.isBefore(_prescriptionDate)) {
               _validUntil = _prescriptionDate.add(const Duration(days: 30));
            }
          }

          // 3. Diagnosis
          if (prescriptionData.diagnosis != null) {
             _diagnosisController.text = prescriptionData.diagnosis!;
          }

          // 4. Medications
          if (prescriptionData.medications.isNotEmpty) {
            // Clear existing empty meds if any
            if (_medications.length == 1 && _medications.first.medicineName.isEmpty) {
                _medications.clear();
            }
            
            for (var med in prescriptionData.medications) {
              _medications.add(MedicationDetails(
                medicineName: med.name,
                dosage: med.dosage,
                frequency: med.frequency,
                duration: med.duration,
                quantity: med.quantity,
                instructions: med.instructions,
                // Attempt to infer type/timing from instructions if possible, else null
              ));
            }
          }
          
          // 5. Set the upload file
          _prescriptionUpload = PrescriptionUpload(
            filePath: file.path,
            fileName: file.path.split('/').last,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned: ${prescriptionData.medications.length} meds found.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }

      } catch (e) {
        debugPrint('OCR Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to scan prescription'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textMain,
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
          // Auto-adjust valid until if needed
          if (_validUntil.isBefore(_prescriptionDate)) {
            _validUntil = _prescriptionDate.add(const Duration(days: 30));
          }
        }
      });
    }
  }

  bool _validateForm() {
    // Form validation (Text fields)
    if (!_formKey.currentState!.validate()) {
      _showError('Please check the red fields in the form.');
      return false;
    }

    // Date validation
    if (_validUntil.isBefore(_prescriptionDate)) {
      _showError('Valid Until date must be after Prescription Date');
      return false;
    }

    // Doctor details validation
    if (!_doctorDetails.isValid) {
      _showError('Please complete all doctor information fields');
      return false;
    }

    // Medications validation
    if (_medications.isEmpty) {
      _showError('Please add at least one medication');
      return false;
    }

    if (!_medications.every((med) => med.isValid)) {
      _showError('Please complete all fields for every medication');
      return false;
    }

    // Upload validation
    // if (!_prescriptionUpload.hasFile) {
    //   _showError('Please upload a photo of the prescription');
    //   return false;
    // }

    // Declaration validation
    if (!_declarationAccepted) {
      _showError('Please accept the declaration checkbox at the bottom');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Get the ACTIVE Patient Data (Family member or Self)
      final patient = await ref.read(patientDataProvider.future);

      if (patient == null) {
        throw Exception(
            'Patient profile not found. Please ensure the family member has a profile created.');
      }

      // 2. Prepare complete prescription input
      final prescriptionInput = CompletePrescriptionInput(
        metadata: PrescriptionMetadata(
          prescriptionDate: _prescriptionDate,
          validUntil: _validUntil,
          type: _prescriptionType,
        ),
        doctorDetails: _doctorDetails,
        diagnosis: _diagnosisController.text.trim(),
        doctorNotes: _doctorNotesController.text.trim().isNotEmpty
            ? _doctorNotesController.text.trim()
            : null,
        patientNotes: _patientNotesController.text.trim().isNotEmpty
            ? _patientNotesController.text.trim()
            : null,
        medications: _medications,
        safetyFlags: SafetyFlags(
          allergiesMentioned: _allergiesMentioned,
          pregnancyBreastfeeding: _pregnancyBreastfeeding,
          chronicConditionLinked: _chronicConditionLinked,
        ),
        upload: _prescriptionUpload,
        declarationAccepted: _declarationAccepted,
      );

      // 3. Store prescription with metadata
      // The patientId here comes from the active family member's patient record
      await SupabaseService.instance.createPrescription(
        patientId: patient.id,
        diagnosis: prescriptionInput.diagnosis,
        notes: prescriptionInput.patientNotes,
        isPublic: false,
        patientEntered: true,
        items: prescriptionInput.medications.map((m) => m.toJson()).toList(),
        metadata: prescriptionInput.toJson(),
      );

      // 4. Refresh cached data
      ref.invalidate(patientPrescriptionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll("Exception:", "").trim();
        // Friendly error message for RLS issues
        if (errorMsg.contains('policy') || errorMsg.contains('permission')) {
          errorMsg = 'Permission denied. Please ask your administrator to run the Family SQL Policies.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMsg'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REUSABLE DROPDOWN BUILDER (From Doctor Screen) ---
  Widget _customOptionsViewBuilder<T extends Object>(
      BuildContext context,
      AutocompleteOnSelected<T> onSelected,
      Iterable<T> options,
      double width,
      Widget Function(T option) itemBuilder,
      ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        color: Colors.white,
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
    );
  }

  Widget _buildStandardDropdownItem(String text) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }





  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeContextProfileProvider);
    final patient = ref.watch(patientDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Stark clean parchment surface
      appBar: AppBar(
        title: Text(
          'Add Prescription',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF121212)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF121212)),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: patient.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HERO SCAN SECTION ---
                _buildHeroScanSection(),
                const SizedBox(height: 28),
                
                // --- FORM SECTION ---
                Text(
                  'Prescription Details',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Doctor Info
                _buildMedicalSection(
                  title: 'Doctor Information',
                  icon: Iconsax.user,
                  child: DoctorInfoCardWidget(
                    onChanged: (details) {
                      setState(() => _doctorDetails = details);
                    },
                  ),
                ),

                // 2. Diagnosis & Date
                _buildMedicalSection(
                  title: 'Diagnosis & Date',
                  icon: Iconsax.calendar_1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDiagnosisField(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              context: context,
                              label: 'Prescribed On',
                              value: _prescriptionDate,
                              onTap: () => _selectDate(context, false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDatePicker(
                              context: context,
                              label: 'Valid Until',
                              value: _validUntil,
                              onTap: () => _selectDate(context, true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Medications
                _buildMedicalSection(
                  title: 'Medications',
                  icon: Iconsax.box,
                  action: TextButton.icon(
                    onPressed: _addMedication,
                    icon: Icon(Iconsax.add_circle, size: 16),
                    label: Text('Add Drug', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF5200),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_medications.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.box, size: 16, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Text(
                                'No medications added yet',
                                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_medications.length, (index) => 
                           Padding(
                             padding: const EdgeInsets.only(bottom: 12.0),
                             child: MedicationCardWidget(
                                key: ValueKey(_medications[index].id),
                                index: index,
                                initialData: _medications[index],
                                onChanged: (details) => _updateMedication(index, details),
                                onRemove: () => _removeMedication(index),
                               ),
                           )
                        ),
                    ],
                  ),
                ),

                // 4. Notes
                 _buildMedicalSection(
                    title: 'Additional Notes',
                    icon: Iconsax.note,
                    child: Column(
                      children: [
                        TextFormField(
                           controller: _doctorNotesController,
                           decoration: _inputDecoration(
                             hint: "Doctor's instructions...",
                             label: 'Doctor Notes',
                           ),
                           maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                           controller: _patientNotesController,
                           decoration: _inputDecoration(
                             hint: "Personal notes...",
                             label: 'My Notes',
                           ),
                           maxLines: 1,
                        ),
                      ],
                    ),
                 ),

                 // 5. Verification & Declaration
                 _buildMedicalSection(
                    title: 'Verification',
                    icon: Iconsax.shield_security,
                    child: Column(
                      children: [
                        _buildPatientProfileRow(profile),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildDeclaration(),
                        const Divider(height: 24, color: Color(0xFFE2E8F0)),
                        _buildSafetyFlags(),
                      ],
                    ),
                 ),

                 const SizedBox(height: 20),
                 
                 // Submit Button
                 SizedBox(
                   width: double.infinity,
                   height: 52,
                   child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF121212),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save Prescription', 
                              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)
                            ),
                   ),
                 ),
                 const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildMedicalSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5200).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: const Color(0xFFFF5200)),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF121212),
                ),
              ),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildPatientProfileRow(AsyncValue<dynamic> profile) {
    return profile.when(
      data: (p) => p != null
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5200).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.user, size: 16, color: const Color(0xFFFF5200)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      p.fullName,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF121212)),
                    ),
                  ],
                ),
              ],
            )
          : const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
            optionsViewBuilder: (context, onSelected, options) {
              return _customOptionsViewBuilder(
                context,
                onSelected,
                options,
                constraints.maxWidth,
                    (option) => _buildStandardDropdownItem(option),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              controller.addListener(() {
                 if (_diagnosisController.text != controller.text) {
                   _diagnosisController.text = controller.text;
                 }
              });
              if (_diagnosisController.text.isNotEmpty && controller.text.isEmpty) {
                controller.text = _diagnosisController.text;
              }
              
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                onEditingComplete: onEditingComplete,
                decoration: _inputDecoration(
                  hint: 'e.g. Viral Fever',
                  label: 'Diagnosis / Condition',
                ),
                validator: (value) => value == null || value.isEmpty ? 'Diagnosis required' : null,
              );
            },
          );
        }
    );
  }

  Widget _buildHeroScanSection() {
    final bool hasFile = _prescriptionUpload.hasFile;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFD1FAE5).withValues(alpha: 0.2) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFile ? const Color(0xFF10B981) : const Color(0xFFFF5200).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSourceSelectionSheet,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasFile ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFFF5200).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasFile ? Iconsax.document_text5 : Iconsax.document_filter,
                    size: 22,
                    color: hasFile ? const Color(0xFF10B981) : const Color(0xFFFF5200),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFile ? 'DIGITAL SCAN CAPTURED' : 'SCAN PRESCRIPTION',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: hasFile ? const Color(0xFF059669) : const Color(0xFFFF5200),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasFile ? (_prescriptionUpload.fileName ?? 'File attached') : 'Tap to scan photo or PDF with AI OCR',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, String? label, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5200), width: 1.5),
      ),
      suffixIcon: suffix,
      isDense: true,
    );
  }

  Widget _buildDatePicker({
    required BuildContext context,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Iconsax.calendar_1, size: 14, color: const Color(0xFF121212)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(value),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: const Color(0xFF121212),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFlags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSafetyCheckTile('ALLERGIES DETECTED?', _allergiesMentioned, (v) => setState(() => _allergiesMentioned = v)),
        const Divider(height: 24, color: Color(0xFFE2E8F0)),
        _buildSafetyCheckTile('PREGNANCY / BREASTFEEDING?', _pregnancyBreastfeeding, (v) => setState(() => _pregnancyBreastfeeding = v)),
        const Divider(height: 24, color: Color(0xFFE2E8F0)),
        _buildSafetyCheckTile('CHRONIC CONDITION LINK?', _chronicConditionLinked, (v) => setState(() => _chronicConditionLinked = v)),
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF121212),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             _buildRadioBtn(true, value, onChanged, 'YES'),
             const SizedBox(width: 8),
             _buildRadioBtn(false, value, onChanged, 'NO'),
          ],
        )
      ],
    );
  }

  Widget _buildRadioBtn(bool optionVal, bool? currentVal, Function(bool?) onChanged, String label) {
     final isSelected = currentVal == optionVal;
     return InkWell(
        onTap: () => onChanged(optionVal),
        borderRadius: BorderRadius.circular(10),
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
           decoration: BoxDecoration(
             color: isSelected 
                 ? (optionVal ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                 : Colors.transparent,
             borderRadius: BorderRadius.circular(10),
             border: Border.all(
               color: isSelected 
                  ? (optionVal ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                  : const Color(0xFFE2E8F0),
             ),
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

  Widget _buildDeclaration() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _declarationAccepted,
              onChanged: (value) {
                setState(() => _declarationAccepted = value ?? false);
              },
              activeColor: const Color(0xFFFF5200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _declarationAccepted = !_declarationAccepted);
              },
              child: Text(
                'I declare that this is a valid medical prescription.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF121212), fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}