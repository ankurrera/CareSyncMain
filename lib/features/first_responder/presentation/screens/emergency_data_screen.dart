// lib/features/first_responder/presentation/screens/emergency_data_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';

final emergencyDataProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, qrCodeId) async {
  return await SupabaseService.instance.getEmergencyData(qrCodeId);
});

class EmergencyDataScreen extends ConsumerWidget {
  final String qrCodeId;
  const EmergencyDataScreen({super.key, required this.qrCodeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyData = ref.watch(emergencyDataProvider(qrCodeId));

    return Scaffold(
      backgroundColor: AppColors.firstResponder,
      body: SafeArea(
        child: emergencyData.when(
          data: (data) {
            if (data == null) return _buildNotFound(context);
            return _buildEmergencyData(context, data); // FIXED: Method restored below
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => _buildError(context),
        ),
      ),
    );
  }

  Widget _buildEmergencyData(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patient'] as Map<String, dynamic>?;
    final conditions = data['conditions'] as List? ?? [];
    final medications = data['medications'] as List? ?? [];

    return Column(
      children: [
        // Premium Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          decoration: const BoxDecoration(
            color: AppColors.firstResponder,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'EMERGENCY MEDICAL ID',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer for centering
                ],
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Icon(Icons.person_rounded, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                patient?['full_name'] ?? 'Unidentified Patient',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (patient?['blood_type'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.water_drop_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'BLOOD TYPE: ${patient!['blood_type']}',
                        style: const TextStyle(
                          color: AppColors.firstResponder,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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
            padding: const EdgeInsets.all(24),
            children: [
              if (conditions.isNotEmpty) ...[
                const _SectionHeader(title: 'CONDITIONS & ALLERGIES', icon: Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(height: 16),
                ...conditions.map((c) => _buildConditionTile(c)),
                const SizedBox(height: 32),
              ],
              
              if (medications.isNotEmpty) ...[
                const _SectionHeader(title: 'CURRENT MEDICATIONS', icon: Icons.medication_rounded, color: Colors.blue),
                const SizedBox(height: 16),
                ...medications.map((m) => _buildMedicationTile(m)),
                const SizedBox(height: 32),
              ],
              
              if (patient?['emergency_contact'] != null) ...[
                const _SectionHeader(title: 'EMERGENCY CONTACT', icon: Icons.contact_phone_rounded, color: Colors.green),
                const SizedBox(height: 16),
                _buildContactTile(patient!['emergency_contact']),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionTile(Map<String, dynamic> condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.priority_high_rounded, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition['description'] ?? 'Unknown Condition',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Severity: ${condition['severity']?.toString().toUpperCase() ?? 'NORMAL'}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication_rounded, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication['medicine'] ?? 'Unknown Med',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${medication['dosage'] ?? ''} • ${medication['frequency'] ?? ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact['name'] ?? 'Emergency Contact',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  contact['relationship'] ?? 'Contact',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.phone_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          const Text('Error loading patient data', style: TextStyle(color: Colors.white, fontSize: 18)),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back', style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          const Text('Patient Record Not Found', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ensure the QR code is a valid CareSync Medical ID.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Dashboard')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
