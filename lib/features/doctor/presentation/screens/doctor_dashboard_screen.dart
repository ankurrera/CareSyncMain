import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../patient/providers/appointment_provider.dart';
import '../../../shared/models/appointment.dart';

// Provider for today's count
final doctorTodayStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTodaysPrescriptionCount();
});

// Provider for total count
final doctorTotalStatsProvider = FutureProvider<int>((ref) async {
  return await SupabaseService.instance.getTotalPrescriptionCount();
});

// Provider for recent activity (last 3 days)
final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await SupabaseService.instance.getDoctorRecentPrescriptions();
});

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  bool _isOnDuty = true;

  // Premium design colors matching Patient Dashboard
  static const Color kBgColor = Color(0xFFFAFAFA);
  static const Color kSurfaceColor = Colors.white;
  static const Color kPrimaryColor = Color(0xFF0284C7); // Clinical Blue
  static const Color kSuccessColor = Color(0xFF16A34A);
  static const Color kWarningColor = Color(0xFFD97706);
  static const Color kTextPrimary = Color(0xFF111827); // Charcoal
  static const Color kTextSecondary = Color(0xFF6B7280); // Neutral grey
  static const Color kBorderColor = Color(0xFFE5E7EB); // Soft grey border

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final todayStats = ref.watch(doctorTodayStatsProvider);
    final totalStats = ref.watch(doctorTotalStatsProvider);
    final recentActivity = ref.watch(recentActivityProvider);
    final appointmentsAsync = ref.watch(appointmentsProvider);

    final todayDate = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
    final displayName = profile.valueOrNull?.fullName ?? 'Physician';

    return Scaffold(
      backgroundColor: kBgColor,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(doctorTodayStatsProvider);
          ref.invalidate(doctorTotalStatsProvider);
          ref.invalidate(recentActivityProvider);
          ref.invalidate(appointmentsProvider);
        },
        color: kPrimaryColor,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. LIGHT HERO HEADER ─────────────────────────────────────────
              Container(
                width: double.infinity,
                color: Colors.white,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => context.push(RouteNames.profile),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: kPrimaryColor.withOpacity(0.08),
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
                              style: GoogleFonts.plusJakartaSans(
                                color: kPrimaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Good Morning,',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: kTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _isOnDuty = !_isOnDuty),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _isOnDuty ? kSuccessColor : kTextSecondary,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _isOnDuty ? kSuccessColor : kTextSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isOnDuty ? 'On Duty' : 'Away',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: _isOnDuty ? kSuccessColor : kTextSecondary,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayName.startsWith('Dr.') ? displayName : 'Dr. $displayName',
                                style: GoogleFonts.plusJakartaSans(
                                  color: kTextPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Text(
                                'Cardiology Department • St. Mary\'s',
                                style: GoogleFonts.plusJakartaSans(
                                  color: kTextSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildHeaderIcon(Iconsax.message, () => context.push('/chat-list')),
                            const SizedBox(width: 8),
                            _buildHeaderIcon(Iconsax.notification, () => context.push(RouteNames.notifications)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── MAIN CONTENT BODY ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 2. METRICS GRID (2X2) ──────────────────────────────────
                    GridView.count(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.65,
                      children: [
                        _buildMetricCard(
                          title: 'Today\'s Rx',
                          value: todayStats.valueOrNull?.toString() ?? '0',
                          icon: Iconsax.document_text,
                          color: kPrimaryColor,
                          trend: 'Refreshed just now',
                        ),
                        _buildMetricCard(
                          title: 'Total Patients',
                          value: totalStats.valueOrNull?.toString() ?? '0',
                          icon: Iconsax.people,
                          color: kPrimaryColor,
                          trend: 'All-time active',
                        ),
                        _buildMetricCard(
                          title: 'In Clinic',
                          value: '3',
                          icon: Iconsax.location,
                          color: kSuccessColor,
                          trend: 'Awaiting consult',
                        ),
                        _buildMetricCard(
                          title: 'Pending Reports',
                          value: '2',
                          icon: Iconsax.receipt_2,
                          color: kWarningColor,
                          trend: 'Requires review',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 3. QUICK ACTIONS GRID (2X2) ────────────────────────────
                    _sectionLabel('Quick Actions'),
                    const SizedBox(height: 8),
                    GridView.count(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.1,
                      children: [
                        _buildActionCard(
                          title: 'New Rx',
                          subtitle: 'Issue Prescription',
                          icon: Iconsax.add_circle,
                          color: kPrimaryColor,
                          onTap: () => context.push(RouteNames.doctorPatientLookup),
                        ),
                        _buildActionCard(
                          title: 'Find Patient',
                          subtitle: 'Lookup Records',
                          icon: Iconsax.personalcard,
                          color: kPrimaryColor,
                          onTap: () => context.push(RouteNames.doctorPatientLookup),
                        ),
                        _buildActionCard(
                          title: 'Availability',
                          subtitle: 'Clinic Timeslots',
                          icon: Iconsax.calendar_1,
                          color: kPrimaryColor,
                          onTap: () => context.push('/doctor/availability'),
                        ),
                        _buildActionCard(
                          title: 'History Logs',
                          subtitle: 'Signed Records',
                          icon: Iconsax.clock,
                          color: kPrimaryColor,
                          onTap: () => context.push(RouteNames.doctorHistory),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── 4. TODAY'S SCHEDULE ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel('Today\'s Schedule'),
                        Text(
                          todayDate,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    appointmentsAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading schedule: $err',
                          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 13),
                        ),
                      ),
                      data: (list) {
                        final now = DateTime.now();
                        final todayAppointments = list.where((app) {
                          final appDate = app.startTime;
                          return appDate.year == now.year &&
                                 appDate.month == now.month &&
                                 appDate.day == now.day;
                        }).toList();

                        return _buildScheduleContainer(todayAppointments);
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── 5. RECENT ACTIVITY ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionLabel('Recent Patients'),
                        GestureDetector(
                          onTap: () => context.push(RouteNames.doctorHistory),
                          child: Text(
                            'View All',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    recentActivity.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                        ),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading activity: $err',
                          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 13),
                        ),
                      ),
                      data: (data) {
                        if (data.isEmpty) {
                          return _buildEmptyActivity();
                        }
                        return Column(
                          children: data.take(3).map((rx) {
                            final patient = rx['patient'] as Map<String, dynamic>?;
                            final profiles = patient?['profiles'] as Map<String, dynamic>?;
                            final patientName = profiles?['full_name'] as String? ?? 'Unknown Patient';
                            final diagnosis = rx['diagnosis'] as String? ?? 'No diagnosis';
                            final date = DateTime.parse(rx['created_at']);
                            final formattedDate = DateFormat('MMM d, h:mm a').format(date);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: kSurfaceColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: kBorderColor, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.015),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  child: Text(
                                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: kTextSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  patientName,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: kTextPrimary),
                                ),
                                subtitle: Text(
                                  '$diagnosis • $formattedDate',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: kTextSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 12,
                                ),
                                onTap: () {
                                  context.push(
                                    RouteNames.doctorPatientRecord,
                                    extra: {
                                      'patientId': patient?['id'] as String? ?? '',
                                      'patientName': patientName,
                                    },
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: kBorderColor),
          ),
          child: Icon(icon, color: const Color(0xFF374151), size: 18),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: kTextPrimary,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF94A3B8),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: kTextSecondary, size: 14),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: kTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trend,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      color: kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySchedule() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Iconsax.calendar_1,
            size: 28,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 8),
          Text(
            'No appointments today',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your calendar is clear. Enjoy your day!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleContainer(List<Appointment> appointments) {
    if (appointments.isEmpty) {
      return _buildEmptySchedule();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: appointments.map((app) {
          final isCompleted = app.status == 'completed';
          final isCancelled = app.status == 'cancelled';

          Color statusColor;
          String statusText;
          if (isCompleted) {
            statusColor = const Color(0xFF64748B);
            statusText = 'Completed';
          } else if (isCancelled) {
            statusColor = const Color(0xFFEF4444);
            statusText = 'Cancelled';
          } else {
            statusColor = const Color(0xFF0284C7);
            statusText = 'Scheduled';
          }

          final timeFormatted = DateFormat('hh:mm a').format(app.startTime);
          final patientName = app.patient?.fullName ?? 'Unknown Patient';
          final reason = app.notes != null && app.notes!.isNotEmpty ? app.notes! : 'Consultation';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    timeFormatted,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: kTextSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                      Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: statusColor, width: 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'No recent patient activity',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Issued patient records will appear in your clinical list.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
