import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../routing/route_names.dart';

// Provider for doctor prescriptions list
final doctorPrescriptionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return [];
  
  final prescriptions = await supabase
      .from('prescriptions')
      .select('''
        *,
        prescription_items(*),
        patient:patients!inner(
          id,
          profiles!inner(full_name, email)
        )
      ''')
      .eq('doctor_id', userId)
      .order('created_at', ascending: false);
  
  return List<Map<String, dynamic>>.from(prescriptions);
});

class PrescriptionHistoryScreen extends ConsumerWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync = ref.watch(doctorPrescriptionsProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    // Colors
    const Color kBgColor = Color(0xFFF7F8FA);
    const Color kSurfaceColor = Color(0xFFFFFFFF);
    const Color kPrimaryColor = Color(0xFF6366F1);
    const Color kSuccessColor = Color(0xFF10B981);
    const Color kWarningColor = Color(0xFFF59E0B);
    const Color kTextPrimary = Color(0xFF111827);
    const Color kTextSecondary = Color(0xFF6B7280);
    const Color kBorderColor = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Prescription History',
          style: GoogleFonts.plusJakartaSans(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, color: kTextPrimary, size: 18),
            onPressed: () => ref.invalidate(doctorPrescriptionsProvider),
          ),
          const SizedBox(width: 8),
        ],
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: 1),
        ),
      ),
      body: prescriptionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Iconsax.warning_2,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load prescriptions',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(doctorPrescriptionsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
        data: (prescriptions) {
          if (prescriptions.isEmpty) {
            return _buildEmptyState(context, kSurfaceColor, kBorderColor, kTextPrimary, kTextSecondary);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(doctorPrescriptionsProvider),
            color: kPrimaryColor,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              itemCount: prescriptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final rx = prescriptions[index];
                final patient = rx['patient'] as Map<String, dynamic>?;
                final profile = patient?['profiles'] as Map<String, dynamic>?;
                final patientName = profile?['full_name'] as String? ?? 'Unknown Patient';
                final items = rx['prescription_items'] as List? ?? [];
                final status = rx['status'] as String? ?? 'active';
                final createdAt = DateTime.parse(rx['created_at'] as String);

                final patientInitial = patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';

                return Container(
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      context.push(
                        RouteNames.doctorPatientRecord,
                        extra: {
                          'patientId': patient?['id'] as String? ?? '',
                          'patientName': patientName,
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Header: Patient Info + Status Badge
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: kPrimaryColor.withOpacity(0.08),
                                    child: Text(
                                      patientInitial,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: kPrimaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patientName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          dateFormat.format(createdAt),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 2. Diagnosis Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: kBorderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'DIAGNOSIS',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF94A3B8),
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      rx['diagnosis'] as String? ?? 'No diagnosis',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 3. Medications wraps
                              if (items.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: items.map<Widget>((item) {
                                    final isDispensed = item['is_dispensed'] as bool? ?? false;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDispensed
                                            ? kSuccessColor.withOpacity(0.08)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDispensed
                                              ? kSuccessColor.withOpacity(0.3)
                                              : kBorderColor,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isDispensed)
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 10,
                                              color: kSuccessColor,
                                            ),
                                          if (isDispensed) const SizedBox(width: 4),
                                          Text(
                                            '${item['medicine_name']} ${item['dosage']}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDispensed ? kSuccessColor : kTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // 4. Visibility Footer info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                rx['is_public'] == true ? Iconsax.global : Iconsax.lock_1,
                                size: 14,
                                color: rx['is_public'] == true ? kWarningColor : kTextSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rx['is_public'] == true
                                    ? 'Visible to first responders'
                                    : 'Private',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: kTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    Color surface,
    Color border,
    Color textP,
    Color textS,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: const Icon(
                Iconsax.document_text,
                size: 40,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Prescriptions Issued',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textP,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prescriptions you issue to patients will appear in this history list.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: textS,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = const Color(0xFF10B981);
        label = 'Completed';
        break;
      case 'cancelled':
        color = const Color(0xFFEF4444);
        label = 'Cancelled';
        break;
      default:
        color = const Color(0xFF6366F1);
        label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
