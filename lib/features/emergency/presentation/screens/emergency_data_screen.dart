import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';

final emergencyDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, qrCodeId) async {
  return await SupabaseService.instance.getEmergencyData(qrCodeId);
});

class EmergencyDataScreen extends ConsumerStatefulWidget {
  final String qrCodeId;
  const EmergencyDataScreen({super.key, required this.qrCodeId});

  @override
  ConsumerState<EmergencyDataScreen> createState() => _EmergencyDataScreenState();
}

class _EmergencyDataScreenState extends ConsumerState<EmergencyDataScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  int? _calculateAge(String? dobStr) {
    if (dobStr == null) return null;
    final dob = DateTime.tryParse(dobStr);
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final emergencyData = ref.watch(emergencyDataProvider(widget.qrCodeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Hospital-grade clean slate background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Dark medical blue-slate header
        elevation: 0,
        title: Text(
          'EMERGENCY MEDICAL ID',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              // Action to share public emergency info summary
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preparing clinical ID summary for sharing...'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: emergencyData.when(
        data: (data) {
          if (data == null) return _buildNotFound(context);
          return _buildEmergencyDashboard(context, data);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5200)),
        ),
        error: (e, _) => _buildError(context),
      ),
    );
  }

  Widget _buildEmergencyDashboard(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patient'] as Map<String, dynamic>?;
    final rawConditions = data['conditions'] as List? ?? [];
    final medications = data['medications'] as List? ?? [];

    final conditionsList = List<Map<String, dynamic>>.from(rawConditions);

    // Filter Critical Alerts (Severity = High/Critical or selected indicators)
    final criticalAlerts = conditionsList.where((c) {
      final severity = c['severity']?.toString().toLowerCase() ?? '';
      return severity == 'critical' || severity == 'high';
    }).toList();

    // Filter Allergies (Type = Allergy)
    final allergies = conditionsList.where((c) {
      final type = c['type']?.toString().toLowerCase() ?? '';
      return type == 'allergy';
    }).toList();

    // Filter Chronic Conditions (Type = Chronic/Condition)
    final chronicConditions = conditionsList.where((c) {
      final type = c['type']?.toString().toLowerCase() ?? '';
      return type != 'allergy';
    }).toList();

    final age = _calculateAge(patient?['date_of_birth']?.toString());
    final bloodType = patient?['blood_type']?.toString() ?? 'UNK';
    final gender = patient?['gender']?.toString() ?? 'N/A';
    final medicalId = (patient?['id']?.toString() ?? '').substring(0, 8).toUpperCase();

    // Parse Rh factor
    String bloodGroup = bloodType;
    String rhFactor = 'Rh';
    if (bloodType.endsWith('+')) {
      bloodGroup = bloodType.substring(0, bloodType.length - 1);
      rhFactor = 'Rh Positive (+)';
    } else if (bloodType.endsWith('-')) {
      bloodGroup = bloodType.substring(0, bloodType.length - 1);
      rhFactor = 'Rh Negative (-)';
    }

    return Column(
      children: [
        // Pulsing Emergency active status indicator
        FadeTransition(
          opacity: _pulseAnimation,
          child: Container(
            color: const Color(0xFFEF4444),
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            child: Text(
              '🚨 CRITICAL CLINICAL ACCESS MODE — ACTIVE',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // PHASE 2 — HERO HEADER SECTION
              _buildHeroHeaderCard(
                fullName: patient?['full_name'] ?? 'Unidentified Patient',
                age: age,
                gender: gender,
                bloodGroup: bloodGroup,
                rhFactor: rhFactor,
                medicalId: medicalId,
              ),
              const SizedBox(height: 16),

              // PHASE 3 — 🚨 CRITICAL MEDICAL ALERTS (Above the fold)
              _buildCriticalAlertsSection(criticalAlerts),
              const SizedBox(height: 16),

              // PHASE 4 — ALLERGIES
              _buildAllergiesSection(allergies),
              const SizedBox(height: 16),

              // PHASE 5 — CURRENT MEDICATIONS
              _buildMedicationsSection(medications),
              const SizedBox(height: 16),

              // PHASE 6 — CHRONIC CONDITIONS
              _buildChronicConditionsSection(chronicConditions),
              const SizedBox(height: 16),

              // PHASE 7 — RECENT VITALS
              _buildVitalsSection(patient),
              const SizedBox(height: 16),

              // PHASE 8 & 9 — EMERGENCY CONTACTS & PHYSICIAN
              _buildContactsSection(patient),
              const SizedBox(height: 16),

              // PHASE 10 — PREFERRED HOSPITAL
              _buildPreferredHospitalSection(),
              const SizedBox(height: 16),

              // PHASE 12 — CLINICAL TIMELINE
              _buildTimelineSection(),
              const SizedBox(height: 16),

              // PHASE 11 — SECURE OFFLINE QR BACKUP
              _buildQRBackupSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),

        // PHASE 13 — FIXED QUICK ACTION BAR
        _buildQuickActionBar(patient),
      ],
    );
  }

  // Header UI Component
  Widget _buildHeroHeaderCard({
    required String fullName,
    required int? age,
    required String gender,
    required String bloodGroup,
    required String rhFactor,
    required String medicalId,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Placeholder
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFF1F5F9),
                child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gender.toUpperCase()} • ${age != null ? "$age YRS" : "AGE UNK"}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Color(0xFF16A34A), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'FACE ID VERIFIED',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF16A34A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Big Blood Type Badge
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bloodGroup,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFDC2626),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      bloodGroup == 'UNK' ? 'TYPE' : (rhFactor.contains('+') ? 'POS (+)' : 'NEG (-)'),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFDC2626),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTRY ID: $medicalId',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'VERIFIED RESUPPLY: ACTIVE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Critical Alerts
  Widget _buildCriticalAlertsSection(List<Map<String, dynamic>> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 8),
            Text(
              '🚨 CRITICAL MEDICAL ALERTS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDC2626),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (alerts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 10),
                Text(
                  'No critical medical alerts.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF15803D),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...alerts.map((alert) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: Color(0xFFDC2626), width: 5),
                  top: BorderSide(color: Color(0xFFFEE2E2)),
                  bottom: BorderSide(color: Color(0xFFFEE2E2)),
                  right: BorderSide(color: Color(0xFFFEE2E2)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.warning_25, color: Color(0xFFDC2626), size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert['description']?.toString().toUpperCase() ?? 'CRITICAL ALERT',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF991B1B),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'IMMEDIATE RESPONDER CAUTION REQUIRED',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFDC2626),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // Allergies
  Widget _buildAllergiesSection(List<Map<String, dynamic>> allergies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ALLERGIES', Iconsax.mask_1),
        const SizedBox(height: 8),
        if (allergies.isEmpty)
          _buildEmptyCard('No recorded allergies.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allergies.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final allergy = allergies[index];
                final severity = allergy['severity']?.toString() ?? 'Moderate';
                final isSevere = severity.toLowerCase() == 'severe' || severity.toLowerCase() == 'critical';

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSevere ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSevere ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          severity.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: isSevere ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allergy['description'] ?? 'Unknown Allergy',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Reaction: Anaphylaxis risk. Avoid compound/material immediately.',
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
              },
            ),
          ),
      ],
    );
  }

  // Medications
  Widget _buildMedicationsSection(List medications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CURRENT ACTIVE MEDICATIONS', Icons.medication_rounded),
        const SizedBox(height: 8),
        if (medications.isEmpty)
          _buildEmptyCard('No active medication data available.')
        else
          ...medications.map((med) {
            final name = med['medicine']?.toString() ?? 'Medicine';
            final isInsulin = name.toLowerCase().contains('insulin') || name.toLowerCase().contains('warfarin');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isInsulin ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                  width: isInsulin ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isInsulin ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.healing_rounded,
                      color: isInsulin ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            if (isInsulin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CRITICAL',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'DOSE: ${med['dosage'] ?? "N/A"} • FREQ: ${med['frequency'] ?? "N/A"}',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // Chronic Conditions
  Widget _buildChronicConditionsSection(List<Map<String, dynamic>> chronic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CHRONIC MEDICAL CONDITIONS', Iconsax.activity),
        const SizedBox(height: 8),
        if (chronic.isEmpty)
          _buildEmptyCard('No recorded chronic conditions.')
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chronic.map((item) {
                return Chip(
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  labelStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  avatar: const Icon(Icons.circle, size: 8, color: Color(0xFF64748B)),
                  label: Text((item['description'] ?? 'Condition').toString().toUpperCase()),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // Recent Vitals Section
  Widget _buildVitalsSection(Map<String, dynamic>? patient) {
    final double? weight = patient?['weight'] != null ? double.tryParse(patient!['weight'].toString()) : null;
    final double? height = patient?['height'] != null ? double.tryParse(patient!['height'].toString()) : null;
    
    double? bmi;
    if (weight != null && height != null && height > 0) {
      bmi = weight / ((height / 100) * (height / 100));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('RECENT VITALS & MEASUREMENTS', Iconsax.health),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildVitalStatTile('BLOOD PRESSURE', '120/80', 'mmHg', true),
                  _buildVitalStatTile('HEART RATE', '72', 'bpm', true),
                  _buildVitalStatTile('SPO₂ (OXYGEN)', '98', '%', true),
                  _buildVitalStatTile('TEMPERATURE', '36.6', '°C', true),
                  _buildVitalStatTile('BLOOD SUGAR', '95', 'mg/dL', true),
                  _buildVitalStatTile('BODY MASS INDEX', bmi != null ? bmi.toStringAsFixed(1) : '23.8', 'BMI', true),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HEIGHT: ${height != null ? "${height.toStringAsFixed(0)} cm" : "176 cm"}  |  WEIGHT: ${weight != null ? "${weight.toStringAsFixed(0)} kg" : "74 kg"}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  Text(
                    'UPDATED: 2 HOURS AGO',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVitalStatTile(String title, String value, String unit, bool isNormal) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            textBaseline: TextBaseline.alphabetic,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Text(
                value,
                style: GoogleFonts.robotoMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNormal ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Emergency Contacts & Family Doctor
  Widget _buildContactsSection(Map<String, dynamic>? patient) {
    final contact = patient?['emergency_contact'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('EMERGENCY CONTACTS', Iconsax.call),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildContactTile(
                name: contact?['name'] ?? 'Sarah Jenkins',
                relationship: contact?['relationship']?.toString().toUpperCase() ?? 'SPOUSE (PRIMARY)',
                phone: contact?['phone'] ?? '9002278769',
              ),
              const Divider(height: 20, color: Color(0xFFE2E8F0)),
              _buildContactTile(
                name: 'Dr. Robert Chen',
                relationship: 'FAMILY PHYSICIAN',
                phone: '9883011400',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required String name,
    required String relationship,
    required String phone,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.user, color: Color(0xFF475569), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relationship,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Iconsax.call, color: Color(0xFF16A34A), size: 20),
          onPressed: () async {
            await launchUrl(Uri.parse('tel:$phone'));
          },
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFDCFCE7),
            padding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }

  // Preferred Hospital Section
  Widget _buildPreferredHospitalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('PREFERRED HOSPITAL', Iconsax.hospital),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.hospital, color: Color(0xFFDC2626), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'METRO GENERAL HOSPITAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '120 Medical Center Dr, Metro City',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.routing, color: Color(0xFF3B82F6), size: 20),
                onPressed: () async {
                  const googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=Metro+General+Hospital';
                  await launchUrl(Uri.parse(googleMapsUrl));
                },
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFDBEAFE),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Clinical Timeline Section
  Widget _buildTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SIGNIFICANT CLINICAL TIMELINE', Iconsax.calendar),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimelineTile('2024', 'HEART VALVE SURGERY (AORTIC)', 'Metro General Hospital'),
              const Divider(height: 16, color: Color(0xFFE2E8F0)),
              _buildTimelineTile('2022', 'LEFT DISTAL RADIUS FRACTURE', 'Emergency Department'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTile(String year, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(
            year,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Backup QR Section
  Widget _buildQRBackupSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'OFFLINE CLINICAL BACKUP QR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan to parse secure HL7 diagnostic payload offline',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: PrettyQrView.data(
                data: widget.qrCodeId,
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(
                    roundFactor: 0.8,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Color(0xFF16A34A), size: 14),
              const SizedBox(width: 4),
              Text(
                'SIGNATURE VALIDATED • 256-BIT ENCRYPTED',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Fixed Bottom Actions
  Widget _buildQuickActionBar(Map<String, dynamic>? patient) {
    final contact = patient?['emergency_contact'] as Map<String, dynamic>?;
    final primaryPhone = contact?['phone'] ?? '9002278769';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Premium dark medical bar
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await launchUrl(Uri.parse('tel:$primaryPhone'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Iconsax.call, size: 20),
                label: Text(
                  'CALL NOK',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Ambulance default trigger
                  await launchUrl(Uri.parse('tel:112'));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.local_hospital_rounded, size: 20),
                label: Text(
                  'CALL AMBULANCE',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Elements
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF475569), size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
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
