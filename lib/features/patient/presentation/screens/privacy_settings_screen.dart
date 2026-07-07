import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';
import '../../providers/patient_provider.dart';

// ── Design tokens (matching CareSync visual system) ────────────────────────
const _kBg       = Color(0xFFFAFAFA);
const _kInk      = Color(0xFF121212);
const _kOrange   = Color(0xFFFF5200);
const _kSlate    = Color(0xFF64748B);
const _kBorder   = Color(0xFFE2E8F0);
const _kGreen    = Color(0xFF10B981);
const _kRed      = Color(0xFFEF4444);

final patientSettingsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return null;
  
  final result = await supabase
      .from('patients')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  
  return result;
});

final publicPrescriptionsCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return 0;
  
  final patientResult = await supabase
      .from('patients')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  
  if (patientResult == null) return 0;
  
  final result = await supabase
      .from('prescriptions')
      .select('id')
      .eq('patient_id', patientResult['id'])
      .eq('is_public', true);
  
  return (result as List).length;
});

final publicConditionsCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return 0;
  
  final patientResult = await supabase
      .from('patients')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  
  if (patientResult == null) return 0;
  
  final result = await supabase
      .from('medical_conditions')
      .select('id')
      .eq('patient_id', patientResult['id'])
      .eq('is_public', true);
  
  return (result as List).length;
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientSettings = ref.watch(patientSettingsProvider);
    final publicPrescriptions = ref.watch(publicPrescriptionsCountProvider);
    final publicConditions = ref.watch(publicConditionsCountProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Privacy Settings',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _kInk,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _kInk),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _kBorder, height: 1.0),
        ),
      ),
      body: patientSettings.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kOrange)),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Iconsax.warning_2,
                size: 40,
                color: _kRed,
              ),
              const SizedBox(height: 16),
              Text(
                'Error: $error',
                style: GoogleFonts.plusJakartaSans(color: _kInk),
              ),
              TextButton(
                onPressed: () => ref.refresh(patientSettingsProvider),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (patient) {
          final condCount = publicConditions.valueOrNull?.toString() ?? '0';
          final rxCount = publicPrescriptions.valueOrNull?.toString() ?? '0';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.info_circle, color: _kOrange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Control what information is visible when your emergency QR code is scanned by first responders.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kSlate,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency Data Summary Split-Card
                Text(
                  'Emergency Data Summary',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(context, condCount, rxCount),
                const SizedBox(height: 24),

                // Profile Information Group Container
                Text(
                  'Profile Information',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSettingRow(
                        context,
                        icon: Iconsax.user,
                        title: 'Full Name',
                        subtitle: 'Always visible to first responders',
                        isPublic: true,
                        locked: true,
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildSettingRow(
                        context,
                        icon: Iconsax.drop,
                        title: 'Blood Type',
                        subtitle: (patient?['blood_type'] as String?) ?? 'Not set',
                        isPublic: true,
                        locked: true,
                        onEdit: () => _showBloodTypeDialog(context, ref, patient?['blood_type']),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      _buildSettingRow(
                        context,
                        icon: Iconsax.radar5,
                        title: 'Emergency Contact',
                        subtitle: patient?['emergency_contact'] != null
                            ? 'Contact registered'
                            : 'Not set',
                        isPublic: true,
                        locked: true,
                        onEdit: () => _showEmergencyContactDialog(context, ref, patient?['emergency_contact']),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions Group Container
                Text(
                  'Quick Actions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kOrange.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.eye_slash, color: _kOrange, size: 18),
                        ),
                        title: Text(
                          'Make All Conditions Private',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _kInk,
                          ),
                        ),
                        subtitle: Text(
                          'Hide all medical conditions from QR',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _kSlate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Iconsax.arrow_right_3, color: _kSlate, size: 16),
                        onTap: () => _makeAllConditionsPrivate(context, ref),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kGreen.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Iconsax.eye, color: _kGreen, size: 18),
                        ),
                        title: Text(
                          'Make All Conditions Public',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: _kInk,
                          ),
                        ),
                        subtitle: Text(
                          'Show all medical conditions in QR',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _kSlate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Iconsax.arrow_right_3, color: _kSlate, size: 16),
                        onTap: () => _makeAllConditionsPublic(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger Zone Container
                Text(
                  'Danger Zone',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kRed,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECDD3)), // Rose 200
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kRed.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Iconsax.barcode, color: _kRed, size: 18),
                    ),
                    title: Text(
                      'Regenerate QR Code',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: _kInk,
                      ),
                    ),
                    subtitle: Text(
                      'Old QR codes will stop working',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _kSlate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Iconsax.arrow_right_3, color: _kSlate, size: 16),
                    onTap: () => _regenerateQrCode(context, ref),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String conditions, String prescriptions) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Conditions summary item
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.activity, color: _kOrange, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      conditions,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'PUBLIC CONDITIONS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: _kSlate,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: _kBorder),
          // Prescriptions summary item
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.document_text, color: _kOrange, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      prescriptions,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'PUBLIC PRESCRIPTIONS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: _kSlate,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPublic,
    bool locked = false,
    VoidCallback? onEdit,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kOrange.withValues(alpha: 0.06),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _kOrange, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          fontSize: 14.5,
          color: _kInk,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          color: _kSlate,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Iconsax.edit_2, size: 14, color: _kOrange),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                backgroundColor: _kOrange.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(8),
              ),
              onPressed: onEdit,
            ),
          if (onEdit != null) const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5), // Green 50
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD1FAE5)), // Green 100
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked ? Iconsax.lock_1 : (isPublic ? Iconsax.eye : Iconsax.eye_slash),
                  size: 11,
                  color: _kGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  isPublic ? 'Public' : 'Private',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _kGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBloodTypeDialog(BuildContext context, WidgetRef ref, String? currentType) async {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    String? selectedType = currentType;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Blood Type',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: _kInk,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: _kSlate),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: bloodTypes.map((type) {
                      final isSelected = selectedType == type;
                      return ChoiceChip(
                        label: Text(
                          type,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : _kSlate,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: _kOrange,
                        backgroundColor: const Color(0xFFF8FAFC),
                        disabledColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? _kOrange : _kBorder,
                            width: 1,
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          setState(() {
                            selectedType = selected ? type : null;
                          });
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (context.mounted) {
                              Navigator.pop(context, selectedType);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((value) async {
      if (value != null && context.mounted) {
        await _updatePatientField(context, ref, 'blood_type', value);
      }
    });
  }

  Future<void> _showEmergencyContactDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? current) async {
    final nameController = TextEditingController(text: current?['name']);
    final phoneController = TextEditingController(text: current?['phone']);
    final relationshipController = TextEditingController(text: current?['relationship']);

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Emergency Contact',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        color: _kInk,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: _kSlate),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Name Field
                Text(
                  'CONTACT NAME',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    color: _kSlate,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Enter contact name',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: _kSlate.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kOrange, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                  ),
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kInk),
                ),
                const SizedBox(height: 14),

                // Phone Field
                Text(
                  'PHONE NUMBER',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    color: _kSlate,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: _kSlate.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kOrange, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                  ),
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kInk),
                ),
                const SizedBox(height: 14),

                // Relationship Field
                Text(
                  'RELATIONSHIP',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    color: _kSlate,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: relationshipController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Spouse, Parent',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: _kSlate.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kOrange, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                  ),
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kInk),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          color: _kSlate,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final contact = {
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'relationship': relationshipController.text.trim(),
                        };
                        await _updatePatientField(context, ref, 'emergency_contact', contact);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kInk,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updatePatientField(BuildContext context, WidgetRef ref, String field, dynamic value) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      await supabase
          .from('patients')
          .upsert({
            'user_id': userId,
            field: value,
          }, onConflict: 'user_id');

      ref.invalidate(patientSettingsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = _kInk,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDestructive ? _kRed : _kInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _kSlate,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kSlate,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text(
                      confirmText,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makeAllConditionsPrivate(BuildContext context, WidgetRef ref) async {
    final confirm = await _showConfirmDialog(
      context,
      title: 'Make All Private',
      message: 'This will hide all your medical conditions from first responders scanning your QR code.',
      confirmText: 'Confirm',
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final patientResult = await supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (patientResult == null) return;

      await supabase
          .from('medical_conditions')
          .update({'is_public': false})
          .eq('patient_id', patientResult['id']);

      ref.invalidate(publicConditionsCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All conditions are now private'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPublic(BuildContext context, WidgetRef ref) async {
    final confirm = await _showConfirmDialog(
      context,
      title: 'Make All Public',
      message: 'This will make all your medical conditions visible to first responders scanning your QR code.',
      confirmText: 'Confirm',
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final patientResult = await supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (patientResult == null) return;

      await supabase
          .from('medical_conditions')
          .update({'is_public': true})
          .eq('patient_id', patientResult['id']);

      ref.invalidate(publicConditionsCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All conditions are now public'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _regenerateQrCode(BuildContext context, WidgetRef ref) async {
    final confirm = await _showConfirmDialog(
      context,
      title: 'Regenerate QR Code',
      message: 'This will create a new QR code and invalidate your old one. '
          'Any printed cards or stickers with the old QR code will stop working. '
          'Are you sure?',
      confirmText: 'Regenerate',
      confirmColor: _kRed,
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final newQrCodeId = const Uuid().v4();

      await supabase
          .from('patients')
          .update({'qr_code_id': newQrCodeId})
          .eq('user_id', userId);

      ref.invalidate(patientSettingsProvider);
      ref.invalidate(patientDataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code regenerated successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _kRed, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
