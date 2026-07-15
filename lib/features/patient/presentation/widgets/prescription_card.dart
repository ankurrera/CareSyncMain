import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/prescription.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import 'prescription_details_sheet.dart';

class PrescriptionCard extends StatelessWidget {
  final Prescription prescription;

  const PrescriptionCard({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dateFormat = DateFormat('MMM d, yyyy');
    final status = prescription.computedStatus;
    final doctorName = prescription.displayDoctorName;
    final doctorInitial =
        doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D';

    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: EdgeInsets.zero,
      onTap: () => _showDetails(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Doctor Info + Status Badge + Type Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: t.tint,
                      child: Text(
                        doctorInitial,
                        style: TextStyle(
                          color: t.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            [
                              dateFormat.format(
                                prescription.prescriptionDate ??
                                    prescription.createdAt,
                              ),
                              if (prescription.displayClinicName != null &&
                                  prescription.displayClinicName!
                                      .trim()
                                      .isNotEmpty)
                                prescription.displayClinicName!.trim(),
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StatusBadge(status: status),
                        if (prescription.prescriptionType != null &&
                            prescription.prescriptionType!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            prescription.prescriptionType!
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: t.monoMeta.copyWith(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w700,
                              color: t.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Diagnosis Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: t.scaffold,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DIAGNOSIS',
                              style: t.monoMeta.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: t.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              prescription.displayDiagnosis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (prescription.validUntil != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'VALID UNTIL',
                              style: t.monoMeta.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: t.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dateFormat.format(prescription.validUntil!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // 3. Medications
                if (prescription.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'PRESCRIBED MEDICATIONS',
                    style: t.monoMeta.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: t.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        prescription.items.take(3).map((item) {
                          final instructionLine = [
                            if (item.frequency.isNotEmpty) item.frequency,
                            if (item.duration != null &&
                                item.duration!.trim().isNotEmpty)
                              item.duration!.trim(),
                            if (item.foodTiming != null &&
                                item.foodTiming!.trim().isNotEmpty)
                              item.foodTiming!.trim(),
                          ].join(' • ');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: t.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: item.medicineName,
                                          style: TextStyle(
                                            fontFamily: 'DM Sans',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: t.textPrimary,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: ' (${item.dosage})',
                                              style: TextStyle(
                                                fontFamily: 'DM Sans',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: t.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (instructionLine.isNotEmpty ||
                                          (item.instructions != null &&
                                              item.instructions!
                                                  .trim()
                                                  .isNotEmpty))
                                        const SizedBox(height: 2),
                                      if (instructionLine.isNotEmpty)
                                        Text(
                                          instructionLine,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: t.textSecondary,
                                          ),
                                        ),
                                      if (item.instructions != null &&
                                          item.instructions!.trim().isNotEmpty)
                                        Text(
                                          'Directives: ${item.instructions!.trim()}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w500,
                                            color: t.textSecondary,
                                            fontStyle: FontStyle.italic,
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
                  if (prescription.items.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '+ ${prescription.items.length - 3} more',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],

                // 4. Clinical Notes
                () {
                  final notes =
                      prescription.doctorNotes ??
                      prescription.patientNotes ??
                      prescription.notes;
                  if (notes == null || notes.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: t.scaffold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Iconsax.note_1,
                            size: 12,
                            color: t.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: t.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              ],
            ),
          ),

          // 5. Footer Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.divider)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.document_text,
                      size: 14,
                      color: t.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prescription.items.length.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'items',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      prescription.isPublic
                          ? Iconsax.global
                          : Iconsax.security_user,
                      size: 12,
                      color: t.textSecondary,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: t.accent,
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

  void _showDetails(BuildContext context) {
    showAppSheet<void>(
      context,
      showHandle: false,
      builder: (_) => PrescriptionDetailsSheet(prescription: prescription),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PrescriptionStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Color color;
    switch (status) {
      case PrescriptionStatus.active:
        color = t.accent;
        break;
      case PrescriptionStatus.expired:
        color = t.error;
        break;
      case PrescriptionStatus.upcoming:
        color = t.accent;
        break;
      case PrescriptionStatus.completed:
      case PrescriptionStatus.cancelled:
        color = t.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: t.monoMeta.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
