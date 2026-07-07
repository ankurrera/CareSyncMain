import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:url_launcher/url_launcher.dart';


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
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  int? _calculateAge(String? dobStr) {
    if (dobStr == null) return null;
    final dob = DateTime.tryParse(dobStr);
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final emergencyData = ref.watch(emergencyDataProvider(widget.qrCodeId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        body: emergencyData.when(
          data: (data) {
            if (data == null) return _buildNotFound(context);
            return _buildEmergencyDashboard(context, data);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFEF4444)),
          ),
          error: (e, _) => _buildError(context),
        ),
      ),
    );
  }

  Widget _buildEmergencyDashboard(BuildContext context, Map<String, dynamic> data) {
    final patient = data['patient'] as Map<String, dynamic>?;
    final rawConditions = data['conditions'] as List? ?? [];
    final medications = data['medications'] as List? ?? [];

    final conditionsList = List<Map<String, dynamic>>.from(rawConditions);

    final criticalAlerts = conditionsList.where((c) {
      final severity = c['severity']?.toString().toLowerCase() ?? '';
      return severity == 'critical' || severity == 'high';
    }).toList();

    final allergies = conditionsList.where((c) {
      final type = c['type']?.toString().toLowerCase() ?? '';
      return type == 'allergy';
    }).toList();

    final chronicConditions = conditionsList.where((c) {
      final type = c['type']?.toString().toLowerCase() ?? '';
      return type != 'allergy';
    }).toList();

    final age = _calculateAge(patient?['date_of_birth']?.toString());
    final bloodType = patient?['blood_type']?.toString() ?? 'UNK';
    final gender = patient?['gender']?.toString() ?? '';
    final avatarUrl = patient?['avatar_url']?.toString();
    final medicalId = (patient?['id']?.toString() ?? '').substring(0, 8).toUpperCase();

    String bloodGroup = bloodType;
    String rhFactor = '';
    if (bloodType.endsWith('+')) {
      bloodGroup = bloodType.substring(0, bloodType.length - 1);
      rhFactor = '+';
    } else if (bloodType.endsWith('-')) {
      bloodGroup = bloodType.substring(0, bloodType.length - 1);
      rhFactor = '−';
    }

    final contact = patient?['emergency_contact'] as Map<String, dynamic>?;
    final primaryPhone = contact?['phone']?.toString();
    final vitals = (data['vitals'] as Map<String, dynamic>?) ?? {};
    final physician = data['physician'] as Map<String, dynamic>?;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          _buildHeaderSection(
            fullName: patient?['full_name'] ?? 'Unidentified Patient',
            age: age,
            gender: gender,
            bloodGroup: bloodGroup,
            rhFactor: rhFactor,
            medicalId: medicalId,
            avatarUrl: avatarUrl,
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF6F8FC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    if (criticalAlerts.isNotEmpty) ...[
                      _buildCriticalAlertsSection(criticalAlerts),
                      const SizedBox(height: 16),
                    ],
                    _buildAllergiesSection(allergies),
                    const SizedBox(height: 16),
                    _buildMedicationsSection(medications),
                    const SizedBox(height: 16),
                    _buildChronicConditionsSection(chronicConditions),
                    const SizedBox(height: 16),
                    _buildVitalsSection(vitals),
                    const SizedBox(height: 16),
                    _buildPhysicalSection(patient),
                    const SizedBox(height: 16),
                    _buildPhysicianSection(physician),
                    const SizedBox(height: 16),
                    _buildContactsSection(patient),
                    const SizedBox(height: 16),
                    _buildQRBackupSection(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          _buildQuickActionBar(primaryPhone),
        ],
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeaderSection({
    required String fullName,
    required int? age,
    required String gender,
    required String bloodGroup,
    required String rhFactor,
    required String medicalId,
    String? avatarUrl,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF8F9FE)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF1E293B), size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF1E293B), size: 22),
                    onPressed: () {
                      ref.invalidate(emergencyDataProvider(widget.qrCodeId));
                    },
                    tooltip: 'Refresh clinical data',
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          const Color(0xFFEF4444).withValues(alpha: 0.15),
                          const Color(0xFFEF4444).withValues(alpha: 0.35),
                          _pulseAnimation.value,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EMERGENCY ACCESS',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Patient identity row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEF4444), width: 2.0),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (gender.isNotEmpty)
                              _headerChip(gender.toUpperCase(), const Color(0xFF3B82F6)),
                            if (gender.isNotEmpty) const SizedBox(width: 6),
                            if (age != null)
                              _headerChip('$age YRS', const Color(0xFF8B5CF6)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ID: $medicalId',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Blood type badge
                  if (bloodGroup != 'UNK') ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            bloodGroup,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Text(
                            rhFactor,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── CRITICAL ALERTS ───────────────────────────────────────────────────────

  Widget _buildCriticalAlertsSection(List<Map<String, dynamic>> alerts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('CRITICAL ALERTS', Iconsax.warning_2, const Color(0xFFEF4444)),
        const SizedBox(height: 10),
        ...alerts.map((alert) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(14),
                border: const Border(
                  left: BorderSide(color: Color(0xFFDC2626), width: 4),
                  top: BorderSide(color: Color(0xFFFECACA), width: 1),
                  right: BorderSide(color: Color(0xFFFECACA), width: 1),
                  bottom: BorderSide(color: Color(0xFFFECACA), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.warning_2, color: Color(0xFFDC2626), size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      alert['description']?.toString() ?? 'Critical Alert',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF991B1B),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (alert['severity']?.toString() ?? 'HIGH').toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ─── ALLERGIES ─────────────────────────────────────────────────────────────

  Widget _buildAllergiesSection(List<Map<String, dynamic>> allergies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('ALLERGIES', Iconsax.mask_1, const Color(0xFFF59E0B)),
        const SizedBox(height: 10),
        if (allergies.isEmpty)
          _buildEmptyCard('No recorded allergies.', Iconsax.tick_circle)
        else
          _buildCard(
            child: Column(
              children: List.generate(allergies.length, (i) {
                final allergy = allergies[i];
                final severity = allergy['severity']?.toString() ?? '';
                final isSevere = severity.toLowerCase() == 'severe' ||
                    severity.toLowerCase() == 'critical';
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSevere
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Iconsax.warning_2,
                              size: 18,
                              color: isSevere
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              allergy['description']?.toString() ?? 'Unknown Allergy',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (severity.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSevere
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSevere
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFFDE68A),
                                ),
                              ),
                              child: Text(
                                severity.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSevere
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFFB45309),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  // ─── MEDICATIONS ───────────────────────────────────────────────────────────

  Widget _buildMedicationsSection(List medications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'ACTIVE MEDICATIONS', Icons.medication_rounded, const Color(0xFF8B5CF6)),
        const SizedBox(height: 10),
        if (medications.isEmpty)
          _buildEmptyCard('No active medications on record.', Iconsax.document)
        else
          ...medications.map((med) {
            final name = med['medicine']?.toString() ?? 'Unknown';
            final dosage = med['dosage']?.toString();
            final frequency = med['frequency']?.toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: Color(0xFF8B5CF6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (dosage != null || frequency != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (dosage != null) 'Dose: $dosage',
                              if (frequency != null) frequency,
                            ].join('  •  '),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

  // ─── CHRONIC CONDITIONS ────────────────────────────────────────────────────

  Widget _buildChronicConditionsSection(List<Map<String, dynamic>> chronic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'MEDICAL CONDITIONS', Iconsax.activity, const Color(0xFF3B82F6)),
        const SizedBox(height: 10),
        if (chronic.isEmpty)
          _buildEmptyCard('No recorded chronic conditions.', Iconsax.activity)
        else
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chronic.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      (item['description'] ?? 'Condition').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ─── PHYSICAL MEASUREMENTS ────────────────────────────────────────────────

  // ─── VITALS ───────────────────────────────────────────────────────────────

  Widget _buildVitalsSection(Map<String, dynamic> vitals) {
    final vitalDefs = [
      {
        'key': 'blood_pressure',
        'label': 'BLOOD PRESSURE',
        'unit': 'mmHg',
        'icon': Icons.favorite_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'key': 'heart_rate',
        'label': 'HEART RATE',
        'unit': 'bpm',
        'icon': Iconsax.heart,
        'color': const Color(0xFFEC4899),
      },
      {
        'key': 'glucose',
        'label': 'BLOOD GLUCOSE',
        'unit': 'mg/dL',
        'icon': Iconsax.drop,
        'color': const Color(0xFFF59E0B),
      },
      {
        'key': 'weight',
        'label': 'WEIGHT',
        'unit': 'kg',
        'icon': Iconsax.weight,
        'color': const Color(0xFF10B981),
      },
    ];

    final availableVitals = vitalDefs
        .where((def) => vitals.containsKey(def['key']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('LATEST VITALS', Iconsax.health, const Color(0xFFEF4444)),
        const SizedBox(height: 10),
        if (availableVitals.isEmpty)
          _buildEmptyCard('No vitals recorded yet.', Iconsax.health)
        else
          _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableVitals.map((def) {
                  final entry = vitals[def['key']] as Map<String, dynamic>?;
                  final value = entry?['value']?.toString() ?? '—';
                  final unit = entry?['unit']?.toString() ?? def['unit'] as String;
                  final recordedAt = entry?['recorded_at']?.toString();
                  final color = def['color'] as Color;
                  final icon = def['icon'] as IconData;
                  final label = def['label'] as String;

                  DateTime? parsedDate;
                  if (recordedAt != null) {
                    parsedDate = DateTime.tryParse(recordedAt)?.toLocal();
                  }
                  final dateStr = parsedDate != null
                      ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}'
                      : null;

                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 60) / 2,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: color, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            value,
                            style: GoogleFonts.robotoMono(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                unit,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (dateStr != null) ...[
                                const Spacer(),
                                Text(
                                  dateStr,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    color: const Color(0xFFB0BEC5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ─── ATTENDING PHYSICIAN ──────────────────────────────────────────────────

  Widget _buildPhysicianSection(Map<String, dynamic>? physician) {
    if (physician == null) return const SizedBox.shrink();

    final name = physician['full_name']?.toString();
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'ATTENDING PHYSICIAN', Iconsax.user_octagon, const Color(0xFF6366F1)),
        const SizedBox(height: 10),
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.user_octagon,
                      color: Color(0xFF6366F1), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. $name',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Most recent prescribing physician',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── PHYSICAL MEASUREMENTS ────────────────────────────────────────────────

  Widget _buildPhysicalSection(Map<String, dynamic>? patient) {
    final weight = patient?['weight'] != null
        ? double.tryParse(patient!['weight'].toString())
        : null;
    final height = patient?['height'] != null
        ? double.tryParse(patient!['height'].toString())
        : null;

    double? bmi;
    if (weight != null && height != null && height > 0) {
      bmi = weight / ((height / 100) * (height / 100));
    }

    final hasData = weight != null || height != null;

    if (!hasData) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('PHYSICAL MEASUREMENTS', Iconsax.weight, const Color(0xFF10B981)),
        const SizedBox(height: 10),
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (height != null)
                  Expanded(
                    child: _buildPhysicalTile(
                      Iconsax.ruler,
                      'HEIGHT',
                      '${height.toStringAsFixed(0)} cm',
                      const Color(0xFF10B981),
                    ),
                  ),
                if (height != null && weight != null)
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                if (weight != null)
                  Expanded(
                    child: _buildPhysicalTile(
                      Iconsax.weight,
                      'WEIGHT',
                      '${weight.toStringAsFixed(1)} kg',
                      const Color(0xFF3B82F6),
                    ),
                  ),
                if (bmi != null) ...[
                  Container(
                    width: 1,
                    height: 50,
                    color: const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  Expanded(
                    child: _buildPhysicalTile(
                      Iconsax.activity,
                      'BMI',
                      bmi.toStringAsFixed(1),
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhysicalTile(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ─── EMERGENCY CONTACTS ───────────────────────────────────────────────────

  Widget _buildContactsSection(Map<String, dynamic>? patient) {
    final contact = patient?['emergency_contact'] as Map<String, dynamic>?;

    if (contact == null) return const SizedBox.shrink();

    final contactName = contact['name']?.toString();
    final contactRelationship = contact['relationship']?.toString();
    final contactPhone = contact['phone']?.toString();

    if (contactName == null && contactPhone == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('EMERGENCY CONTACT', Iconsax.call, const Color(0xFF22C55E)),
        const SizedBox(height: 10),
        _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.user, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (contactName != null)
                        Text(
                          contactName,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      if (contactRelationship != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          contactRelationship.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (contactPhone != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          contactPhone,
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (contactPhone != null)
                  GestureDetector(
                    onTap: () async {
                      await launchUrl(Uri.parse('tel:$contactPhone'));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Iconsax.call, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── QR BACKUP ────────────────────────────────────────────────────────────

  Widget _buildQRBackupSection() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_rounded,
                    color: Color(0xFF0F172A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'PATIENT QR CODE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Scan to identify this patient in any CareSync station',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
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
                const Icon(Icons.lock_outline_rounded,
                    color: Color(0xFF22C55E), size: 14),
                const SizedBox(width: 6),
                Text(
                  'END-TO-END ENCRYPTED • CARESYNC VERIFIED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF22C55E),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK ACTION BAR ─────────────────────────────────────────────────────

  Widget _buildQuickActionBar(String? primaryPhone) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (primaryPhone != null)
              Expanded(
                child: _buildActionButton(
                  icon: Iconsax.call,
                  label: 'CALL NOK',
                  color: const Color(0xFF22C55E),
                  onTap: () async {
                    await launchUrl(Uri.parse('tel:$primaryPhone'));
                  },
                ),
              ),
            if (primaryPhone != null) const SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.local_hospital_rounded,
                label: 'AMBULANCE',
                color: const Color(0xFFDC2626),
                onTap: () async {
                  await launchUrl(Uri.parse('tel:112'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.15)!],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED HELPERS ───────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon, Color accentColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 14),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF475569),
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 18),
          const SizedBox(width: 10),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.close_circle,
                    size: 48, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 20),
              Text(
                'Unable to Load Data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'An error occurred loading this patient record. Please try again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.search_status,
                    size: 48, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Text(
                'Patient Not Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The scanned QR code does not match any registered CareSync patient.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Back to Dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
