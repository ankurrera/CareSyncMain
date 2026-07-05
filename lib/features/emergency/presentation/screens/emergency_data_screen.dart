import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';

final emergencyDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, qrCodeId) async {
  return await SupabaseService.instance.getEmergencyData(qrCodeId);
});

class EmergencyDataScreen extends ConsumerWidget {
  final String qrCodeId;
  const EmergencyDataScreen({super.key, required this.qrCodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyData = ref.watch(emergencyDataProvider(qrCodeId));

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: Text(
          'Emergency Medical ID',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: emergencyData.when(
        data: (data) {
          if (data == null) return _buildNotFound(context);
          return _buildEmergencyData(context, data);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5200)),
        ),
        error: (e, _) => _buildError(context),
      ),
    );
  }

  Widget _buildEmergencyData(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patient'] as Map<String, dynamic>?;
    final conditions = data['conditions'] as List? ?? [];
    final medications = data['medications'] as List? ?? [];

    return Column(
      children: [
        // Premium Header Info Card
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                child: const Icon(Icons.person_rounded,
                    size: 44, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                patient?['full_name'] ?? 'Unidentified Patient',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              if (patient?['blood_type'] != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop_rounded,
                          color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'BLOOD TYPE: ${patient!['blood_type']}',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              if (conditions.isNotEmpty) ...[
                _buildSectionHeader('CONDITIONS & ALLERGIES',
                    Iconsax.warning_2, const Color(0xFFEF4444)),
                const SizedBox(height: 12),
                ...conditions.map((c) => _buildConditionTile(c)),
                const SizedBox(height: 28),
              ],
              if (medications.isNotEmpty) ...[
                _buildSectionHeader('CURRENT MEDICATIONS',
                    Icons.medication_rounded, const Color(0xFF3B82F6)),
                const SizedBox(height: 12),
                ...medications.map((m) => _buildMedicationTile(m)),
                const SizedBox(height: 28),
              ],
              if (patient?['emergency_contact'] != null) ...[
                _buildSectionHeader('EMERGENCY CONTACT', Iconsax.call,
                    const Color(0xFF10B981)),
                const SizedBox(height: 12),
                _buildContactTile(patient!['emergency_contact']),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionTile(Map<String, dynamic> condition) {
    final severity = condition['severity']?.toString().toLowerCase() ?? 'normal';
    Color severityColor = const Color(0xFF10B981);
    if (severity == 'critical' || severity == 'high') {
      severityColor = const Color(0xFFEF4444);
    } else if (severity == 'medium' || severity == 'moderate') {
      severityColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.info_circle,
                color: Color(0xFFEF4444), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition['description'] ?? 'Unknown Condition',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Type: ${(condition['type'] ?? 'allergy').toString().toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: severityColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              severity.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: severityColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationTile(Map<String, dynamic> medication) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.mask_1,
                color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication['medicine'] ?? 'Unknown Med',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${medication['dosage'] ?? ''} • ${medication['frequency'] ?? ''}',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Map<String, dynamic> contact) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.user,
                color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'] ?? 'Emergency Contact',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF121212),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact['relationship'] ?? 'Contact',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final phone = contact['phone'];
              if (phone != null) await launchUrl(Uri.parse('tel:$phone'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
              elevation: 0,
            ),
            child: const Icon(Iconsax.call, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.close_circle, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              'Error loading patient data',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121212),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go Back',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFFF5200),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.search_status, size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            Text(
              'Patient Record Not Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121212),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure the scanned QR code is a valid CareSync Medical ID.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF121212),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Back to Dashboard', style: GoogleFonts.plusJakartaSans()),
            ),
          ],
        ),
      ),
    );
  }
}
