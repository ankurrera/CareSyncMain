import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../models/prescription.dart';
import '../../providers/patient_provider.dart';

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(patientPrescriptionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Prescriptions',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF121212)),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF121212)),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_circle, size: 22, color: Color(0xFFFF5200)),
            onPressed: () => context.push(RouteNames.patientAddPrescription),
          ),
        ],
      ),
      body: prescriptions.when(
        data: (list) {
          if (list.isEmpty) return _buildEmptyState(context);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(patientPrescriptionsProvider),
            color: const Color(0xFFFF5200),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => PrescriptionCard(prescription: list[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
        error: (e, _) => _buildErrorState(ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.patientAddPrescription),
        icon: const Icon(Iconsax.add, color: Colors.white, size: 20),
        label: Text('Add New', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Iconsax.document_text, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 18),
            Text(
              'No Prescriptions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF121212),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first prescription to track your medications and medical history.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 36, color: Color(0xFFEF4444)),
          const SizedBox(height: 14),
          Text('Failed to load data', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: const Color(0xFF121212))),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => ref.invalidate(patientPrescriptionsProvider),
            child: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFFFF5200))),
          ),
        ],
      ),
    );
  }
}

class PrescriptionCard extends StatelessWidget {
  final Prescription prescription;

  const PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final status = prescription.computedStatus;
    final doctorName = prescription.displayDoctorName;
    final doctorInitial = doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D';

    return Container(
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
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header: Doctor Info + Status Badge
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF1F5F9),
                        child: Text(
                          doctorInitial,
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctorName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF121212),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(prescription.prescriptionDate ?? prescription.createdAt),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(status: status),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Diagnosis Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DIAGNOSIS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          prescription.displayDiagnosis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF121212),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Medications (Chips)
                  if (prescription.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Prescribed Medications',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: prescription.items.take(3).map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '${item.medicineName} ${item.dosage}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (prescription.items.length > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '+ ${prescription.items.length - 3} more',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFFFF5200), fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            
            // 4. Footer Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.document_text, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(
                        prescription.items.length.toString(),
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF121212)),
                      ),
                      const SizedBox(width: 4),
                      Text('items', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'View Details',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFFF5200),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFF5200)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrescriptionDetailsSheet(prescription: prescription),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PrescriptionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case PrescriptionStatus.active: color = const Color(0xFF10B981); break;
      case PrescriptionStatus.expired: color = const Color(0xFFEF4444); break;
      case PrescriptionStatus.upcoming: color = const Color(0xFFF59E0B); break;
      case PrescriptionStatus.completed: color = const Color(0xFF64748B); break;
      case PrescriptionStatus.cancelled: color = const Color(0xFF94A3B8); break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _PrescriptionDetailsSheet extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionDetailsSheet({required this.prescription});

  Future<void> _launchPdf(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (e) {
        launched = false;
      }

      if (!launched) {
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw 'Could not open PDF';
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error opening PDF: $e', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, yyyy');

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prescription Details',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Body
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                // 1. core Details
                _buildSectionLabel('MEDICAL DETAILS'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        'Diagnosis',
                        prescription.displayDiagnosis,
                        icon: Iconsax.heart,
                        isBold: true,
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                      _buildInfoRow(
                        'Doctor',
                        prescription.displayDoctorName,
                        subtitle: prescription.displayClinicName,
                        icon: Iconsax.user,
                      ),
                      if (prescription.doctorDetails?.specialization != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Text(
                            prescription.doctorDetails!.specialization!,
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Validity
                _buildSectionLabel('VALIDITY'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetaItem('Prescribed On', dateFormat.format(prescription.prescriptionDate ?? prescription.createdAt)),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _buildMetaItem(
                            'Valid Until',
                            prescription.validUntil != null ? dateFormat.format(prescription.validUntil!) : 'N/A',
                            isAlert: prescription.validUntil?.isBefore(DateTime.now()) ?? false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Medications List
                _buildSectionLabel('MEDICATIONS (${prescription.items.length})'),
                if (prescription.items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No medications listed', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
                    ),
                  )
                else
                  ...prescription.items.asMap().entries.map(
                        (e) => _buildMedicationTile(e.value, e.key + 1),
                  ),
                const SizedBox(height: 12),

                // 4. Notes
                if (prescription.notes != null || prescription.doctorNotes != null || prescription.patientNotes != null) ...[
                  _buildSectionLabel('ADDITIONAL NOTES'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prescription.doctorNotes?.isNotEmpty == true)
                          _buildNoteItem('Doctor Note', prescription.doctorNotes!),
                        if (prescription.patientNotes?.isNotEmpty == true)
                          _buildNoteItem('My Note', prescription.patientNotes!),
                        if (prescription.notes?.isNotEmpty == true)
                          _buildNoteItem('General', prescription.notes!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 5. Safety Flags
                if (prescription.safetyFlags != null)
                  _buildSafetyFlags(prescription.safetyFlags!),

                // 6. Attachments
                if (prescription.uploadInfo?.hasFile == true) ...[
                  const SizedBox(height: 24),
                  _buildSectionLabel('ATTACHMENTS'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5200).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF5200).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.document_text5, color: Color(0xFFFF5200), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prescription.uploadInfo?.fileName ?? 'Attached File', 
                            style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF5200), fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Sticky Bottom Actions
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: prescription.pdfUrl != null ? () => _launchPdf(context, prescription.pdfUrl!) : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      foregroundColor: const Color(0xFF121212),
                    ),
                    child: Text('Download PDF', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { /* Share Copy */ },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF121212),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text('Share Copy', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0xFFE2E8F0)),
  );

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {String? subtitle, required IconData icon, bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                  color: const Color(0xFF121212),
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItem(String label, String value, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF121212),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationTile(PrescriptionItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: Text('$index', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.medicineName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF121212))),
                const SizedBox(height: 2),
                Text('${item.dosage} • ${item.frequency}', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),

                if (item.displayInstructions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item.displayInstructions!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
              ],
            ),
          ),
          if (item.duration != null)
            Text(
                '${item.duration} days',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFF5200))
            ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF121212), fontWeight: FontWeight.w500, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            TextSpan(text: content, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFlags(SafetyFlags flags) {
    if (flags.allergiesMentioned != true && flags.pregnancyBreastfeeding != true && flags.chronicConditionLinked != true) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('SAFETY ALERTS'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            children: [
              if(flags.allergiesMentioned == true) _buildSafetyRow('Allergies Detected'),
              if(flags.pregnancyBreastfeeding == true) _buildSafetyRow('Pregnancy/Breastfeeding Warning'),
              if(flags.chronicConditionLinked == true) _buildSafetyRow('Chronic Condition Linked'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2, size: 14, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Text(
            text, 
            style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFB91C1C)),
          ),
        ],
      ),
    );
  }
}