import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../routing/route_names.dart';
import '../../../family/providers/family_provider.dart';
import '../widgets/family_member_list.dart';
import '../widgets/daily_medication_schedule.dart';
import '../widgets/vitals_summary_card.dart';
import '../../../shared/presentation/widgets/appointment_list_widget.dart';
import '../../providers/patient_provider.dart';
import '../../../shared/providers/chat_provider.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  bool _hasPrompted = false;

  void _showBiometricSetupPrompt() {
    if (_hasPrompted) return;
    _hasPrompted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF4F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.security_safe,
                      color: Color(0xFFFF5200),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Setup Face ID',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF121212),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Your emergency biometric profile is not set up. Register your face scan so that first responders can instantly identify you and access your emergency ID in case of a critical medical situation.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Remind Later',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(RouteNames.kycVerification);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5200),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Enroll Now',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeContextProfileProvider);
    final isKycVerifiedAsyncValue = ref.watch(isKycVerifiedProvider);
    final isKycVerified = isKycVerifiedAsyncValue.valueOrNull ?? false;

    // Ask for the data modally if user profile loaded and is not verified
    if (isKycVerifiedAsyncValue.hasValue && !isKycVerified && !_hasPrompted) {
      _showBiometricSetupPrompt();
    }

    const todayDate = 'Monday, 7 Apr 2026';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. DARK HERO HEADER CORNER ───────────────────────────────────
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Navigation Row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push(RouteNames.profile),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.15), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFFF5200),
                                child: Text(
                                  profile.valueOrNull?.fullName.isNotEmpty == true
                                      ? profile.valueOrNull!.fullName.substring(0, 1).toUpperCase()
                                      : 'A',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi, ${profile.valueOrNull?.fullName.split(' ').first ?? 'Ankur'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  todayDate,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/chat-list'),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: const Icon(Iconsax.message_2, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => context.push(RouteNames.notifications),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: const Icon(Iconsax.notification, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Emergency Access Pass Card (V2 glassmorphism styling)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push(RouteNames.patientQrCode),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF5200).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFFF5200).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          'EMERGENCY PASS',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: const Color(0xFFFF5200),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      const Icon(Iconsax.barcode, color: Colors.white70, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Emergency ID Access',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Iconsax.scan, size: 12, color: Colors.white.withOpacity(0.5)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Tap to generate QR code or scan face',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. SCROLLABLE CONTENT BODY ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biometrics caution banner (contextual warning)
                  if (!isKycVerified) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4F0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF5200).withOpacity(0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Iconsax.warning_2,
                            color: Color(0xFFFF5200),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Facial Scan Missing',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF121212),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Set up biometrics now to ensure first responders can identify you during an emergency.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () => context.push(RouteNames.kycVerification),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Start Enrollment',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFFF5200),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Iconsax.arrow_right_1,
                                        color: Color(0xFFFF5200),
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Profiles list (Family Switcher Carousel)
                  const FamilyMemberList(),
                  const SizedBox(height: 16),

                  // Today's Medications Checklist
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Medications",
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
                      ),
                      TextButton(
                        onPressed: () => context.push(RouteNames.patientPrescriptions),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'View All',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF5200),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const DailyMedicationSchedule(),
                  const SizedBox(height: 24),

                  // Patient Status (Vitals Grid)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Patient Status",
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
                      ),
                      TextButton(
                        onPressed: () => context.push('/patient/vitals-history'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'See History',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF5200),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const VitalsSummaryCard(),
                  const SizedBox(height: 24),

                  // Upcoming Appointments
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Appointments',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
                      ),
                      TextButton(
                        onPressed: () => context.push('/patient/book-appointment'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Book New',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF5200),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const AppointmentListWidget(),
                  const SizedBox(height: 24),

                  // My Doctors List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "My Doctors",
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'See All',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFFF5200),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDoctorItem('Dr. Priya Sharma', 'Cardiologist • 12 yrs exp.', 'PS', context),
                  const SizedBox(height: 10),
                  _buildDoctorItem('Dr. Rohan Verma', 'General Physician • 8 yrs exp.', 'RV', context),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patient/book-appointment'),
        backgroundColor: const Color(0xFF121212),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Iconsax.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Iconsax.home, 'Home', true, () => context.go(RouteNames.patientDashboard)),
              _buildNavItem(Iconsax.document_text, 'Records', false, () => context.push(RouteNames.patientMedicalHistory)),
              const SizedBox(width: 48),
              _buildNavItem(Iconsax.user, 'Profile', false, () => context.push(RouteNames.profile)),
              _buildNavItem(Iconsax.radar5, 'Emergency', false, () => context.push(RouteNames.patientEmergency)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? const Color(0xFFFF5200) : const Color(0xFF94A3B8), size: 24),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isActive ? const Color(0xFFFF5200) : const Color(0xFF94A3B8),
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorItem(String name, String subtitle, String initials, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFF1F5F9),
            child: Text(
              initials,
              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF121212))),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.message_2, size: 16, color: Color(0xFFFF5200)),
            onPressed: () => context.push('/chat-list'),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFF5200).withOpacity(0.08),
              padding: const EdgeInsets.all(8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}