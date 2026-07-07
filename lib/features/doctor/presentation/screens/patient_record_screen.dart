import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'dart:math';
import '../../../../routing/route_names.dart';
import '../../../../services/encryption_service.dart';
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

  Future<List<Vital>> _decryptVitals(List<Vital> encrypted) async {
    final list = <Vital>[];
    for (var v in encrypted) {
      try {
        final val = await EncryptionService.instance.decryptMedicalRecord(
          encryptedData: v.value,
          patientId: patientId,
        );
        list.add(v.copyWith(value: val));
      } catch (e) {
        list.add(v.copyWith(value: 'Error'));
      }
    }
    return list;
  }

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
                    data: (v) => FutureBuilder<List<Vital>>(
                      future: _decryptVitals(v),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error decrypting vitals: ${snapshot.error}'));
                        }
                        final decryptedVitals = snapshot.data ?? [];
                        return _buildVitalsChartOrGrid(decryptedVitals, kSurfaceColor, kBorderColor, kTextPrimary, kTextSecondary);
                      },
                    ),
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

    final name = patient.fullName ?? patientName;
    final patientInitials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    final ageStr = _calculateAge(patient.dateOfBirth);
    final genderStr = patient.gender != null 
        ? (patient.gender!.substring(0, 1).toUpperCase() + patient.gender!.substring(1).toLowerCase())
        : 'N/A';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Patient Info Top Bar ───────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  patientInitials.substring(0, min(2, patientInitials.length)),
                  style: GoogleFonts.manrope(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.manrope(
                        color: textP,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Record ID: ${patient.id.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.manrope(
                        color: textS,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Demographics Grid ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), // Slate 50
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 12,
              children: [
                _buildInfoGridItem('Age', ageStr),
                _buildInfoGridItem('Gender', genderStr),
                _buildInfoGridItem('Blood Type', patient.bloodType ?? 'N/A'),
                _buildInfoGridItem('Weight', patient.weight != null ? "${patient.weight!.toStringAsFixed(0)} kg" : 'N/A'),
                _buildInfoGridItem('Height', patient.height != null ? "${patient.height!.toStringAsFixed(0)} cm" : 'N/A'),
                _buildInfoGridItem('DOB', patient.dateOfBirth != null ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!) : 'N/A'),
              ],
            ),
          ),
          
          // ── Emergency Contact ──────────────────────────────────────────────
          if (patient.emergencyContact != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2), // Rose 50 for alert safety feel
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3)), // Rose 200
              ),
              child: Row(
                children: [
                  Icon(Icons.emergency_rounded, color: const Color(0xFFE11D48), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Contact',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF9F1239), // Rose 800
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${patient.emergencyContact!.name} (${patient.emergencyContact!.relationship ?? "Contact"})',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          patient.emergencyContact!.phone,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoGridItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsChartOrGrid(List<Vital> vitals, Color surface, Color border, Color textP, Color textS) {
    if (vitals.isEmpty) return _buildEmptyCard('No vitals recorded', surface, border, textP, textS);

    // Group vitals by type
    final grouped = <String, List<Vital>>{};
    for (var v in vitals) {
      grouped.putIfAbsent(v.type, () => []).add(v);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final type = entry.key;
        final list = entry.value.reversed.toList(); // Chronological order (left to right)
        final latest = entry.value.first; // Latest is first in raw list

        // Parse values
        final values = <double>[];
        final secondaryValues = <double>[];
        
        for (var v in list) {
          if (type == 'blood_pressure') {
            final parts = v.value.split('/');
            final sys = double.tryParse(parts[0]) ?? 120.0;
            final dia = parts.length > 1 ? (double.tryParse(parts[1]) ?? 80.0) : 80.0;
            values.add(sys);
            secondaryValues.add(dia);
          } else {
            final val = double.tryParse(v.value) ?? 0.0;
            values.add(val);
          }
        }

        // Color coding matching premium palettes
        Color chartColor = const Color(0xFF6366F1); // Default Indigo
        if (type == 'heart_rate') chartColor = const Color(0xFFEF4444); // Red
        if (type == 'blood_pressure') chartColor = const Color(0xFF3B82F6); // Blue
        if (type == 'glucose') chartColor = const Color(0xFFF59E0B); // Amber
        if (type == 'weight') chartColor = const Color(0xFF10B981); // Emerald

        final title = type.replaceAll('_', ' ').toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            latest.value,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: textP,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            latest.unit,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: textS,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: chartColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${list.length} Logs',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: chartColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Inline Line Chart
              SizedBox(
                height: 52,
                width: double.infinity,
                child: CustomPaint(
                  painter: _VitalsChartPainter(
                    values: values,
                    secondaryValues: type == 'blood_pressure' ? secondaryValues : null,
                    color: chartColor,
                    secondaryColor: type == 'blood_pressure' ? const Color(0xFF38BDF8) : null,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
      children: conditions.map((c) {
        final isAllergy = c.conditionType == 'allergy';
        final displayColor = isAllergy ? const Color(0xFFEF4444) : warningColor;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textP,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.conditionTypeDisplayName}${c.severity != null ? " • Severity: ${c.severity}" : ""}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textS,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF475569), // Slate 600
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildEmptyCard(String message, Color surface, Color border, Color textP, Color textS) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Slate 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF94A3B8), // Slate 400
            fontSize: 12,
            fontWeight: FontWeight.w600,
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

class _VitalsChartPainter extends CustomPainter {
  final List<double> values;
  final List<double>? secondaryValues; // For diastolic BP
  final Color color;
  final Color? secondaryColor;

  _VitalsChartPainter({
    required this.values,
    this.secondaryValues,
    required this.color,
    this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Find min and max for scaling
    double minVal = values.reduce(min);
    double maxVal = values.reduce(max);
    if (secondaryValues != null && secondaryValues!.isNotEmpty) {
      final minSec = secondaryValues!.reduce(min);
      final maxSec = secondaryValues!.reduce(max);
      minVal = min(minVal, minSec);
      maxVal = max(maxVal, maxSec);
    }

    // Add padding to min/max
    final range = maxVal - minVal;
    minVal = minVal - (range * 0.15);
    maxVal = maxVal + (range * 0.15);
    if (maxVal == minVal) {
      minVal -= 10;
      maxVal += 10;
    }

    final double width = size.width;
    final double height = size.height;

    // Draw main line
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = (values.length > 1) ? (i / (values.length - 1)) * width : width / 2;
      final y = height - ((values[i] - minVal) / (maxVal - minVal)) * height;
      points.add(Offset(x, y));
    }

    _drawSmoothLine(canvas, points, paint, size, color);

    // Draw secondary line if provided
    if (secondaryValues != null && secondaryValues!.length == values.length) {
      final secPaint = Paint()
        ..color = secondaryColor ?? color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      final secPoints = <Offset>[];
      for (int i = 0; i < secondaryValues!.length; i++) {
        final x = (secondaryValues!.length > 1) ? (i / (secondaryValues!.length - 1)) * width : width / 2;
        final y = height - ((secondaryValues![i] - minVal) / (maxVal - minVal)) * height;
        secPoints.add(Offset(x, y));
      }

      _drawSmoothLine(canvas, secPoints, secPaint, size, secondaryColor ?? color.withValues(alpha: 0.5), fill: false);
    }
  }

  void _drawSmoothLine(Canvas canvas, List<Offset> points, Paint paint, Size size, Color lineColor, {bool fill = true}) {
    if (points.isEmpty) return;
    
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    if (points.length == 1) {
      canvas.drawCircle(points[0], 3.0, paint..style = PaintingStyle.fill);
      return;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(path, paint);

    // Fill area under the curve
    if (fill && points.length > 1) {
      final fillPath = Path.from(path);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.15),
            lineColor.withValues(alpha: 0.00),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw a small dot on the last point
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(points.last, 3.5, dotPaint);
    
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(points.last, 3.5, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _VitalsChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.secondaryValues != secondaryValues;
  }
}
