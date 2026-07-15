import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../widgets/daily_medication_schedule.dart';
import '../widgets/vitals_summary_card.dart';
import '../../../shared/presentation/widgets/appointment_list_widget.dart';
import '../../providers/patient_provider.dart';
import '../../providers/appointment_provider.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() =>
      _PatientDashboardScreenState();
}

class _PatientDashboardScreenState
    extends ConsumerState<PatientDashboardScreen> {
  bool _hasPrompted = false;
  bool _isVerifiedUser = false;

  void _showBiometricSetupPrompt() {
    if (_hasPrompted) return;
    _hasPrompted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final t = context.tokens;
      showAppSheet<void>(
        context,
        builder:
            (ctx) => AppSheetContent(
              icon: Iconsax.security_safe,
              title: 'Setup Face ID',
              message:
                  'Your emergency biometric profile is not set up. Register your face scan so that first responders can instantly identify you and access your emergency ID in case of a critical medical situation.',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: t.divider),
                          foregroundColor: t.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Remind Later',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push(RouteNames.kycVerification);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: t.accent,
                          foregroundColor: t.accentOn,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Enroll Now',
                          style: TextStyle(
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profile = ref.watch(currentProfileProvider);
    final isKycVerifiedAsyncValue = ref.watch(isKycVerifiedProvider);
    final isKycVerified = isKycVerifiedAsyncValue.valueOrNull ?? false;

    final patientDataAsync = ref.watch(patientDataProvider);
    final hasFaceScan = patientDataAsync.valueOrNull?.faceScanUrl != null;
    final doctorsAsync = ref.watch(patientDoctorsProvider);

    // Cache verified states to prevent dialog races during logouts/transitions
    if (isKycVerified || hasFaceScan) {
      _isVerifiedUser = true;
    }

    // Ask for the data modally if user is logged in, KYC loaded, not verified, and has no face scan
    if (profile.valueOrNull != null &&
        patientDataAsync.valueOrNull != null &&
        isKycVerifiedAsyncValue.hasValue &&
        patientDataAsync.hasValue &&
        !isKycVerified &&
        !_isVerifiedUser &&
        !hasFaceScan &&
        !_hasPrompted) {
      _showBiometricSetupPrompt();
    }

    const todayDate = 'Monday, 7 Apr 2026';

    return Scaffold(
      backgroundColor: t.scaffold,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. HERO HEADER ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: t.card,
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
                                border: Border.all(
                                  color: t.divider,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: t.tint,
                                child: Text(
                                  profile.valueOrNull?.fullName.isNotEmpty ==
                                          true
                                      ? profile.valueOrNull!.fullName
                                          .substring(0, 1)
                                          .toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    color: t.accent,
                                    fontWeight: FontWeight.w700,
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
                                  'Hi, ${profile.valueOrNull?.fullName.split(' ').first ?? 'there'}',
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  todayDate,
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push(RouteNames.notifications),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: t.card,
                                shape: BoxShape.circle,
                                border: Border.all(color: t.divider),
                              ),
                              child: Icon(
                                Iconsax.notification,
                                color: t.textPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Emergency Access Pass Card
                      SquircleCard(
                        radius: AppSpacing.squircleGrouped,
                        borderSide: BorderSide(color: t.divider),
                        padding: const EdgeInsets.all(20),
                        onTap: () => context.push(RouteNames.patientQrCode),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.tint,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: t.accent.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    'EMERGENCY PASS',
                                    style: t.monoMeta.copyWith(
                                      color: t.accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Iconsax.barcode,
                                  color: t.textPrimary,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Emergency ID Access',
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Iconsax.scan,
                                  size: 12,
                                  color: t.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap to generate QR code or scan face',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(height: 1, color: t.divider),

            // ── 2. SCROLLABLE CONTENT BODY ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biometrics caution banner (contextual warning)
                  if (patientDataAsync.hasValue &&
                      !isKycVerified &&
                      !hasFaceScan) ...[
                    SquircleCard(
                      radius: AppSpacing.squircleGrouped,
                      color: t.tint,
                      borderSide: BorderSide(
                        color: t.accent.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Iconsax.warning_2, color: t.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Facial Scan Missing',
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Set up biometrics now to ensure first responders can identify you during an emergency.',
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontSize: 11,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap:
                                      () => context.push(
                                        RouteNames.kycVerification,
                                      ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Start Enrollment',
                                        style: TextStyle(
                                          color: t.accent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Iconsax.arrow_right_1,
                                        color: t.accent,
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

                  // Today's Medications Checklist
                  _sectionHeader(
                    context,
                    "Today's Medications",
                    'View All',
                    () => context.push(RouteNames.patientPrescriptions),
                  ),
                  const SizedBox(height: 12),
                  const DailyMedicationSchedule(),
                  const SizedBox(height: 24),

                  // Patient Status (Vitals Grid)
                  _sectionHeader(
                    context,
                    'Patient Status',
                    'See History',
                    () => context.push('/patient/vitals-history'),
                  ),
                  const SizedBox(height: 12),
                  const VitalsSummaryCard(),
                  const SizedBox(height: 24),

                  // Upcoming Appointments
                  _sectionHeader(
                    context,
                    'Upcoming Appointments',
                    'Book New',
                    () => context.push('/patient/book-appointment'),
                  ),
                  const SizedBox(height: 12),
                  const AppointmentListWidget(),
                  const SizedBox(height: 24),

                  // My Doctors List
                  _sectionHeader(context, 'My Doctors', 'See All', () {}),
                  const SizedBox(height: 12),
                  doctorsAsync.when(
                    data: (doctors) {
                      if (doctors.isEmpty) {
                        return _buildEmptyDoctorsState(context);
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: doctors.length > 3 ? 3 : doctors.length,
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = doctors[index];
                          final initials =
                              doc.fullName.isNotEmpty
                                  ? doc.fullName
                                      .split(' ')
                                      .map((e) => e[0])
                                      .take(2)
                                      .join()
                                      .toUpperCase()
                                  : 'D';
                          return _buildDoctorItem(
                            doc.fullName,
                            '${doc.specialization ?? 'General Physician'} • ${doc.hospitalName ?? 'CareSync Clinic'}',
                            initials,
                            context,
                          );
                        },
                      );
                    },
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (err, _) => Center(
                          child: Text(
                            'Error loading doctors: $err',
                            style: TextStyle(color: t.error, fontSize: 12),
                          ),
                        ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    String title,
    String action,
    VoidCallback onTap,
  ) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: t.textPrimary,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              action,
              style: TextStyle(
                color: t.accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorItem(
    String name,
    String subtitle,
    String initials,
    BuildContext context,
  ) {
    final t = context.tokens;

    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Styled Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: t.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: t.textSecondary,
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

  Widget _buildEmptyDoctorsState(BuildContext context) {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Iconsax.user,
              size: 28,
              color: t.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'No consulting doctors',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Doctors you consult with will be listed here.',
              style: TextStyle(
                color: t.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
