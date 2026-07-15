import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/supabase_service.dart';
import '../../models/prescription.dart';

class _PrescriptionDetailsSheet extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionDetailsSheet({required this.prescription});

  Future<void> _launchPdf(BuildContext context, String url) async {
    // Show a loading spinner dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final signedUrl = await SupabaseService.instance.getPrescriptionSignedUrl(
        url,
      );
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if (signedUrl == null) {
        throw 'Failed to generate signed access link';
      }

      final uri = Uri.parse(signedUrl);
      bool launched = false;
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dateFormat = DateFormat('MMMM d, yyyy');

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Prescription Details', style: t.sheetTitle),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: t.textSecondary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: t.scaffold,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: t.divider),

          // Scrollable Body
          Expanded(
            child: ListView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                // 1. core Details
                _buildSectionLabel(context, 'MEDICAL DETAILS'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        context,
                        'Diagnosis',
                        prescription.displayDiagnosis,
                        icon: Iconsax.heart,
                        isBold: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: t.divider),
                      ),
                      _buildInfoRow(
                        context,
                        'Doctor',
                        prescription.displayDoctorName,
                        subtitle: prescription.displayClinicName,
                        icon: Iconsax.user,
                      ),
                      if (prescription.doctorDetails?.specialization != null ||
                          prescription
                                  .doctorDetails
                                  ?.medicalRegistrationNumber !=
                              null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (prescription.doctorDetails?.specialization !=
                                      null &&
                                  prescription.doctorDetails!.specialization!
                                      .trim()
                                      .isNotEmpty)
                                Text(
                                  prescription.doctorDetails!.specialization!
                                      .trim(),
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (prescription
                                          .doctorDetails
                                          ?.medicalRegistrationNumber !=
                                      null &&
                                  prescription
                                      .doctorDetails!
                                      .medicalRegistrationNumber!
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Registration No: ${prescription.doctorDetails!.medicalRegistrationNumber!.trim()}',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Validity
                _buildSectionLabel(context, 'VALIDITY'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(context),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetaItem(
                          context,
                          'Prescribed On',
                          dateFormat.format(
                            prescription.prescriptionDate ??
                                prescription.createdAt,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 32, color: t.divider),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _buildMetaItem(
                            context,
                            'Valid Until',
                            prescription.validUntil != null
                                ? dateFormat.format(prescription.validUntil!)
                                : 'N/A',
                            isAlert:
                                prescription.validUntil?.isBefore(
                                  DateTime.now(),
                                ) ??
                                false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Medications List
                _buildSectionLabel(
                  context,
                  'MEDICATIONS (${prescription.items.length})',
                ),
                if (prescription.items.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No medications listed',
                        style: TextStyle(color: t.textSecondary),
                      ),
                    ),
                  )
                else
                  ...prescription.items.asMap().entries.map(
                    (e) => _buildMedicationTile(context, e.value, e.key + 1),
                  ),
                const SizedBox(height: 12),

                // 4. Notes
                if (prescription.notes != null ||
                    prescription.doctorNotes != null ||
                    prescription.patientNotes != null) ...[
                  _buildSectionLabel(context, 'ADDITIONAL NOTES'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prescription.doctorNotes?.isNotEmpty == true)
                          _buildNoteItem(
                            context,
                            'Doctor Note',
                            prescription.doctorNotes!,
                          ),
                        if (prescription.patientNotes?.isNotEmpty == true)
                          _buildNoteItem(
                            context,
                            'My Note',
                            prescription.patientNotes!,
                          ),
                        if (prescription.notes?.isNotEmpty == true)
                          _buildNoteItem(
                            context,
                            'General',
                            prescription.notes!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 5. Safety Flags
                if (prescription.safetyFlags != null)
                  _buildSafetyFlags(context, prescription.safetyFlags!),

                // 6. Attachments
                if (prescription.uploadInfo?.hasFile == true) ...[
                  const SizedBox(height: 24),
                  _buildSectionLabel(context, 'ATTACHMENTS'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.tint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.document_text5, color: t.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            prescription.uploadInfo?.fileName ??
                                'Attached File',
                            style: TextStyle(
                              color: t.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
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
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CSSecondaryButton(
                    label: 'Download PDF',
                    onPressed:
                        prescription.pdfUrl != null
                            ? () => _launchPdf(context, prescription.pdfUrl!)
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CSPrimaryButton(
                    label: 'Share Copy',
                    onPressed: () {
                      /* Share Copy */
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final t = context.tokens;
    return BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: t.divider),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label,
        style: t.monoSectionHeader.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: t.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    String? subtitle,
    required IconData icon,
    bool isBold = false,
  }) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: t.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: t.textPrimary,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaItem(
    BuildContext context,
    String label,
    String value, {
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
            color: t.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isAlert ? t.error : t.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationTile(
    BuildContext context,
    PrescriptionItem item,
    int index,
  ) {
    final t = context.tokens;
    final typeAndRoute = [
      if (item.displayMedicineType != null) item.displayMedicineType!,
      if (item.displayRoute != null) item.displayRoute!,
    ].join(' • ');

    final subtitleParts = [
      item.dosage,
      if (typeAndRoute.isNotEmpty) typeAndRoute,
      item.frequency,
      if (item.foodTiming != null && item.foodTiming!.trim().isNotEmpty)
        item.foodTiming!.trim(),
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.medicineName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleParts,
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.displayInstructions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: t.scaffold,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.divider),
                      ),
                      child: Text(
                        item.displayInstructions!,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.textSecondary,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if ((item.duration != null && item.duration!.trim().isNotEmpty) ||
              (item.quantity != null && item.quantity! > 0))
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.duration != null && item.duration!.trim().isNotEmpty)
                  Text(
                    item.duration!.toLowerCase().contains('day')
                        ? item.duration!.trim()
                        : '${item.duration!.trim()} days',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                  ),
                if (item.quantity != null && item.quantity! > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: t.scaffold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'QTY: ${item.quantity}',
                      style: t.monoMeta.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, String label, String content) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 12,
            color: t.textPrimary,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: content, style: TextStyle(color: t.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyFlags(BuildContext context, SafetyFlags flags) {
    final t = context.tokens;
    if (flags.allergiesMentioned != true &&
        flags.pregnancyBreastfeeding != true &&
        flags.chronicConditionLinked != true) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, 'SAFETY ALERTS'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              if (flags.allergiesMentioned == true)
                _buildSafetyRow(context, 'Allergies Detected'),
              if (flags.pregnancyBreastfeeding == true)
                _buildSafetyRow(context, 'Pregnancy/Breastfeeding Warning'),
              if (flags.chronicConditionLinked == true)
                _buildSafetyRow(context, 'Chronic Condition Linked'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyRow(BuildContext context, String text) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Iconsax.warning_2, size: 14, color: t.error),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// Public alias wrapper to keep the details sheet accessible to outer widgets.
class PrescriptionDetailsSheet extends StatelessWidget {
  final Prescription prescription;

  const PrescriptionDetailsSheet({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    return _PrescriptionDetailsSheet(prescription: prescription);
  }
}
