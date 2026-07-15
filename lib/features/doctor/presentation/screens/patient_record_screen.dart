import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'dart:math';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../routing/screen_titles.dart';
import '../../../patient/models/patient_data.dart';
import '../../providers/doctor_patient_provider.dart';
import '../../../../services/connectivity_service.dart';
import '../widgets/vitals_chart_or_grid.dart';

class PatientRecordScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;

  const PatientRecordScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final patientData = ref.watch(doctorPatientDataProvider(patientId));
    final vitals = ref.watch(decryptedDoctorPatientVitalsProvider(patientId));
    final conditions = ref.watch(doctorPatientConditionsProvider(patientId));
    final prescriptions = ref.watch(
      doctorPatientPrescriptionsProvider(patientId),
    );

    final connectivity = ref.watch(connectivityStatusProvider).valueOrNull;
    final isOffline = connectivity == ConnectivityStatus.offline;

    return CSScaffold(
      title: ScreenTitles.doctorPatientRecord,
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            isOffline
                ? null
                : () {
                  context.push(
                    RouteNames.doctorNewPrescription,
                    extra: {'patientId': patientId, 'patientName': patientName},
                  );
                },
        backgroundColor: isOffline ? t.divider : t.accent,
        foregroundColor: isOffline ? t.textSecondary : t.accentOn,
        elevation: 0,
        icon: Icon(
          Iconsax.add,
          size: 18,
          color: isOffline ? t.textSecondary : t.accentOn,
        ),
        label: Text(
          'Issue Prescription',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.2,
            color: isOffline ? t.textSecondary : t.accentOn,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── 1. PATIENT HEADER DETAIL ─────────────────────────────────
            patientData.when(
              data: (data) => _buildHeaderCard(context, data),
              loading:
                  () => LinearProgressIndicator(color: t.accent, minHeight: 2),
              error: (_, __) => const SizedBox.shrink(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 2. RECENT VITALS ───────────────────────────────────
                  _buildSectionLabel(context, 'Recent Vitals'),
                  const SizedBox(height: 12),
                  vitals.when(
                    data:
                        (decryptedVitals) =>
                            VitalsChartOrGrid(vitals: decryptedVitals),
                    loading:
                        () => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accent,
                            ),
                          ),
                        ),
                    error:
                        (e, __) =>
                            Center(child: Text('Error loading vitals: $e')),
                  ),

                  const SizedBox(height: 28),

                  // ── 3. MEDICAL CONDITIONS ──────────────────────────────
                  _buildSectionLabel(context, 'Medical Conditions'),
                  const SizedBox(height: 12),
                  conditions.when(
                    data: (c) => _buildConditionsList(context, c),
                    loading: () => const SizedBox.shrink(),
                    error:
                        (e, __) =>
                            Center(child: Text('Error loading conditions: $e')),
                  ),

                  const SizedBox(height: 28),

                  // ── 4. PRESCRIPTION HISTORY ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel(context, 'Prescription History'),
                      GestureDetector(
                        onTap: () {
                          context.push(
                            RouteNames.doctorHistory,
                            extra: {
                              'patientId': patientId,
                              'patientName': patientName,
                            },
                          );
                        },
                        child: Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  prescriptions.when(
                    data: (p) => _buildPrescriptionList(context, p),
                    loading:
                        () => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accent,
                            ),
                          ),
                        ),
                    error:
                        (e, __) => Center(
                          child: Text('Error loading prescriptions: $e'),
                        ),
                  ),
                  const SizedBox(height: 120), // Padding to clear FAB
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, PatientData? patient) {
    final t = context.tokens;
    if (patient == null) return const SizedBox.shrink();

    final name = patient.fullName ?? patientName;
    final patientInitials =
        name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .join()
            .toUpperCase();
    final ageStr = _calculateAge(patient.dateOfBirth);
    final genderStr =
        patient.gender != null
            ? (patient.gender!.substring(0, 1).toUpperCase() +
                patient.gender!.substring(1).toLowerCase())
            : 'N/A';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.divider, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Patient Info Top Bar ───────────────────────────────────────
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      t.accent.withValues(alpha: 0.15),
                      t.accent.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: t.accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  patientInitials.substring(0, min(2, patientInitials.length)),
                  style: TextStyle(
                    color: t.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.personalcard,
                          size: 12,
                          color: t.textSecondary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'RECORD ID: ${patient.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            color: t.textSecondary.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: t.divider.withValues(alpha: 0.5)),
          const SizedBox(height: 20),

          // ── Demographics Grid ──────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _buildInfoGridItem(context, 'Age', ageStr)),
              const SizedBox(width: 20),
              Expanded(child: _buildInfoGridItem(context, 'Gender', genderStr)),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInfoGridItem(
                  context,
                  'Blood Type',
                  patient.bloodType ?? 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoGridItem(
                  context,
                  'Weight',
                  patient.weight != null
                      ? '${patient.weight!.toStringAsFixed(0)} kg'
                      : 'N/A',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInfoGridItem(
                  context,
                  'Height',
                  patient.height != null
                      ? '${patient.height!.toStringAsFixed(0)} cm'
                      : 'N/A',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInfoGridItem(
                  context,
                  'DOB',
                  patient.dateOfBirth != null
                      ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!)
                      : 'N/A',
                ),
              ),
            ],
          ),

          // ── Emergency Contact ──────────────────────────────────────────
          if (patient.emergencyContact != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.call, color: t.error, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${patient.emergencyContact!.name}${patient.emergencyContact!.relationship != null ? ' · ${patient.emergencyContact!.relationship}' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient.emergencyContact!.phone,
                        style: TextStyle(fontSize: 12, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Emergency Contact',
                  style: TextStyle(
                    fontSize: 10,
                    color: t.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGridItem(BuildContext context, String label, String value) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: t.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
            letterSpacing: -0.15,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionsList(BuildContext context, List<dynamic> conditions) {
    final t = context.tokens;
    if (conditions.isEmpty) {
      return _buildEmptyCard(context, 'No conditions listed');
    }
    return Column(
      children:
          conditions.map((c) {
            final isAllergy = c.conditionType == 'allergy';
            // Allergies flag risk (error); everything else uses the accent.
            final displayColor = isAllergy ? t.error : t.accent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SquircleCard(
                radius: AppSpacing.squircleGrouped,
                borderSide: BorderSide(color: t.divider),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.description,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.conditionTypeDisplayName}${c.severity != null ? " • Severity: ${c.severity}" : ""}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildPrescriptionList(
    BuildContext context,
    List<dynamic> prescriptions,
  ) {
    final t = context.tokens;
    if (prescriptions.isEmpty) {
      return _buildEmptyCard(context, 'No history found');
    }
    return Column(
      children:
          prescriptions.take(3).map((p) {
            final dateStr = DateFormat('MMM dd, yyyy').format(p.createdAt!);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SquircleCard(
                radius: AppSpacing.squircleGrouped,
                borderSide: BorderSide(color: t.divider),
                padding: EdgeInsets.zero,
                onTap: () {},
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    p.diagnosis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: t.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    dateStr,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    Iconsax.clock,
                    color: t.textSecondary,
                    size: 16,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: t.textPrimary.withValues(alpha: 0.8),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          Icon(
            Iconsax.info_circle,
            color: t.textSecondary.withValues(alpha: 0.4),
            size: 15,
          ),
          const SizedBox(width: 10),
          Text(message, style: TextStyle(color: t.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  String _calculateAge(DateTime? dob) {
    if (dob == null) return 'N/A';
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age.toString();
  }
}
