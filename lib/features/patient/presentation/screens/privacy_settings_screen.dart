import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Privacy Settings',
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
      body: patientSettings.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Iconsax.warning_2,
                size: 40,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              Text('Error: $error', style: GoogleFonts.plusJakartaSans()),
              TextButton(
                onPressed: () => ref.refresh(patientSettingsProvider),
                child: Text('Retry', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        data: (patient) {
          final condCount = publicConditions.valueOrNull?.toString() ?? '0';
          final rxCount = publicPrescriptions.valueOrNull?.toString() ?? '0';

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.info_circle, color: Color(0xFF64748B), size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Control what information is visible when your emergency QR code is scanned by first responders.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
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
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSummarySection(context, condCount, rxCount),
                const SizedBox(height: 24),

                // Profile Information Group Container
                Text(
                  'Profile Information',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        subtitle: patient?['blood_type'] ?? 'Not set',
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
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: const Icon(Iconsax.eye_slash, color: Color(0xFFFF5200), size: 20),
                        title: Text('Make All Conditions Private', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Hide all medical conditions from QR', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                        onTap: () => _makeAllConditionsPrivate(context, ref),
                      ),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: const Icon(Iconsax.eye, color: Color(0xFF10B981), size: 20),
                        title: Text('Make All Conditions Public', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('Show all medical conditions in QR', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
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
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const Icon(Iconsax.barcode, color: Color(0xFFEF4444), size: 20),
                    title: Text('Regenerate QR Code', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF121212))),
                    subtitle: Text('Old QR codes will stop working', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
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

  Widget _buildSummarySection(BuildContext context, String conditions, String prescriptions) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  conditions,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF5200),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PUBLIC CONDITIONS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: Column(
              children: [
                Text(
                  prescriptions,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF5200),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PUBLIC PRESCRIPTIONS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.6,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: const Color(0xFFFF5200), size: 20),
      title: Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF121212))),
      subtitle: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Iconsax.edit_2, size: 16, color: Color(0xFFFF5200)),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFF5200).withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(6),
              ),
              onPressed: onEdit,
            ),
          if (onEdit != null) const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isPublic ? const Color(0xFF10B981) : const Color(0xFFFF5200)).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isPublic ? const Color(0xFF10B981) : const Color(0xFFFF5200)).withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked ? Iconsax.lock_1 : (isPublic ? Iconsax.eye : Iconsax.eye_slash),
                  size: 11,
                  color: isPublic ? const Color(0xFF10B981) : const Color(0xFFFF5200),
                ),
                const SizedBox(width: 4),
                Text(
                  isPublic ? 'Public' : 'Private',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPublic ? const Color(0xFF10B981) : const Color(0xFFFF5200),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select Blood Type', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bloodTypes.map((type) {
            return ChoiceChip(
              label: Text(type, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
              selected: selectedType == type,
              selectedColor: const Color(0xFFFF5200).withOpacity(0.1),
              checkmarkColor: const Color(0xFFFF5200),
              onSelected: (selected) {
                selectedType = selected ? type : null;
                Navigator.pop(context, selectedType);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((value) async {
      if (value != null) {
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Emergency Contact', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationshipController,
              decoration: InputDecoration(
                labelText: 'Relationship',
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12),
                hintText: 'e.g., Spouse, Parent',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold)),
          ),
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
              backgroundColor: const Color(0xFF121212),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
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
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPrivate(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Make All Private', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('This will hide all your medical conditions from first responders scanning your QR code.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF121212), foregroundColor: Colors.white),
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPublic(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Make All Public', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('This will make all your medical conditions visible to first responders scanning your QR code.', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF121212), foregroundColor: Colors.white),
            child: Text('Confirm', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _regenerateQrCode(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Regenerate QR Code', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFFEF4444))),
        content: Text(
          'This will create a new QR code and invalidate your old one. '
          'Any printed cards or stickers with the old QR code will stop working. '
          'Are you sure?',
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: Text('Regenerate', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) return;
      
      final newQrCodeId = DateTime.now().millisecondsSinceEpoch.toString();
      
      await supabase
          .from('patients')
          .update({'qr_code_id': newQrCodeId})
          .eq('user_id', userId);
      
      ref.invalidate(patientSettingsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code regenerated successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
