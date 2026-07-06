import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../routing/route_names.dart';
import '../../../patient/models/patient_data.dart';
import '../../../patient/models/vital.dart';
import '../../providers/doctor_patient_provider.dart';

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
    final patientData = ref.watch(doctorPatientDataProvider(patientId));
    final vitals = ref.watch(doctorPatientVitalsProvider(patientId));
    final conditions = ref.watch(doctorPatientConditionsProvider(patientId));
    final prescriptions = ref.watch(doctorPatientPrescriptionsProvider(patientId));

    // Color tokens
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
          patientName,
          style: GoogleFonts.manrope(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.message_2, color: kTextPrimary, size: 20),
            onPressed: () {
              // Navigate to chat with patient
              context.push('/chat-list');
            },
          ),
          const SizedBox(width: 8),
        ],
        shape: const Border(
          bottom: BorderSide(color: kBorderColor, width: 1),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── 1. PATIENT HEADER DETAIL ─────────────────────────────────────
            patientData.when(
              data: (data) => _buildHeaderCard(data, kSurfaceColor, kBorderColor, kTextPrimary, kTextSecondary, kPrimaryColor),
              loading: () => const LinearProgressIndicator(color: kPrimaryColor, minHeight: 2),
              error: (_, __) => const SizedBox.shrink(),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 2. RECENT VITALS ───────────────────────────────────────
                  _buildSectionLabel('Recent Vitals'),
                  const SizedBox(height: 12),
                  vitals.when(
                    data: (v) => _buildVitalsGrid(v, kSurfaceColor, kBorderColor, kTextPrimary, kTextSecondary),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                      ),
                    ),
                    error: (e, __) => Center(child: Text('Error loading vitals: $e')),
                  ),

                  const SizedBox(height: 28),

                  // ── 3. MEDICAL CONDITIONS ──────────────────────────────────
                  _buildSectionLabel('Medical Conditions'),
                  const SizedBox(height: 12),
                  conditions.when(
                    data: (c) => _buildConditionsList(c, kSurfaceColor, kBorderColor, kTextPrimary, kTextSecondary, kWarningColor),
                    loading: () => const SizedBox.shrink(),
                    error: (e, __) => Center(child: Text('Error loading conditions: $e')),
                  ),

                  const SizedBox(height: 28),

                  // ── 4. PRESCRIPTION HISTORY ────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('Prescription History'),
                      GestureDetector(
                        onTap: () {
                          // Route to doctor history screen
                          context.push(RouteNames.doctorHistory);
                        },
                        child: Text(
                          'View All',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  prescriptions.when(
                    data: (p) => _buildPrescriptionList(p, kSurfaceColor, kBorderColor, kTextPrimary, kTextSecondary),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                      ),
                    ),
                    error: (e, __) => Center(child: Text('Error loading prescriptions: $e')),
                  ),
                  const SizedBox(height: 120), // Padding to clear FAB
                ],
              ),
            ),
          ],
        ),
      ),
      // ── 5. PREMIUM BOTTOM ACTIONS ──────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(RouteNames.doctorNewPrescription, extra: {
            'patientId': patientId,
            'patientName': patientName,
          });
        },
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Iconsax.add, color: Colors.white, size: 18),
        label: Text(
          'Issue Prescription',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeaderCard(
    PatientData? patient,
    Color surface,
    Color border,
    Color textP,
    Color textS,
    Color primary,
  ) {
    if (patient == null) return const SizedBox.shrink();
    
    final patientInitials = patientName.split(' ').map((e) => e[0]).join().toUpperCase();
    final ageStr = _calculateAge(patient.dateOfBirth);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              patientInitials.substring(0, patientInitials.length > 2 ? 2 : patientInitials.length),
              style: GoogleFonts.manrope(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        'Age: $ageStr',
                        style: GoogleFonts.manrope(
                          color: textP,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        'Blood: ${patient.bloodType ?? "N/A"}',
                        style: GoogleFonts.manrope(
                          color: textP,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Patient Record Active',
                  style: GoogleFonts.manrope(
                    color: textS,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsGrid(List<Vital> vitals, Color surface, Color border, Color textP, Color textS) {
    if (vitals.isEmpty) return _buildEmptyCard('No vitals recorded', surface, border, textP, textS);

    // Get latest vital of each type
    final latestVitals = <String, Vital>{};
    for (var v in vitals) {
      if (!latestVitals.containsKey(v.type)) {
        latestVitals[v.type] = v;
      }
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: latestVitals.values.map((v) => _buildVitalCard(v, surface, border, textP, textS)).toList(),
    );
  }

  Widget _buildVitalCard(Vital vital, Color surface, Color border, Color textP, Color textS) {
    final title = vital.type.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Icon(Iconsax.lock_1, color: Color(0xFF94A3B8), size: 12),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'LOCKED',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                vital.unit,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: textS,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsList(
    List<dynamic> conditions,
    Color surface,
    Color border,
    Color textP,
    Color textS,
    Color warningColor,
  ) {
    if (conditions.isEmpty) return _buildEmptyCard('No conditions listed', surface, border, textP, textS);
    return Column(
      children: conditions.map((c) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: warningColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              c.conditionType,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textP,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildPrescriptionList(
    List<dynamic> prescriptions,
    Color surface,
    Color border,
    Color textP,
    Color textS,
  ) {
    if (prescriptions.isEmpty) return _buildEmptyCard('No history found', surface, border, textP, textS);
    return Column(
      children: prescriptions.take(3).map((p) {
        final dateStr = DateFormat('MMM dd, yyyy').format(p.createdAt!);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              p.diagnosis,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textP,
              ),
            ),
            subtitle: Text(
              dateStr,
              style: GoogleFonts.manrope(
                color: textS,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(
              Iconsax.clock,
              color: Color(0xFFCBD5E1),
              size: 16,
            ),
            onTap: () {},
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF111827),
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildEmptyCard(String message, Color surface, Color border, Color textP, Color textS) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.manrope(
            color: textS,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _calculateAge(DateTime? dob) {
    if (dob == null) return 'N/A';
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age.toString();
  }
}
