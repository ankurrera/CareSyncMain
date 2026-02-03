import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../family/providers/family_provider.dart';
import '../widgets/family_member_list.dart';
import '../widgets/daily_medication_schedule.dart';
import '../widgets/vitals_summary_card.dart';
import '../../../shared/presentation/widgets/appointment_list_widget.dart';
import '../../providers/patient_provider.dart';
import '../../../shared/providers/chat_provider.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeContextProfileProvider);
    // Dynamic counts from providers
    final prescriptions = ref.watch(patientPrescriptionsProvider).valueOrNull ?? [];
    final records = ref.watch(medicalConditionsProvider).valueOrNull ?? [];
    final chats = ref.watch(chatRoomsProvider).valueOrNull ?? [];
    
    // Explicit date to match mockup: Monday, 7 Apr 2026
    const todayDate = 'Monday, 7 Apr 2026';

    return Scaffold(
      backgroundColor: AppColors.softBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────────
              // 1. HEADER (High Fidelity)
              // ─────────────────────────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push(RouteNames.profile),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFF6366F1), 
                      child: Text(
                        profile.valueOrNull?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${profile.valueOrNull?.fullName.split(' ').first ?? 'Ankur'}',
                          style: const TextStyle(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          todayDate,
                          style: TextStyle(
                            color: AppColors.textSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.push(RouteNames.notifications),
                        icon: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF6366F1)),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 14,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─────────────────────────────────────────────────────────────────
              // 2. EMERGENCY CARD
              // ─────────────────────────────────────────────────────────────────
              _buildHighFidelityEmergencyCard(context),
              const SizedBox(height: 28),
              
              const FamilyMemberList(),
              
              // ─────────────────────────────────────────────────────────────────
              // 3. APPOINTMENTS
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming Appointments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -0.5),
                  ),
                  TextButton(
                    onPressed: () => context.push('/patient/book-appointment'), 
                    child: const Text('Book New', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const AppointmentListWidget(),
              const SizedBox(height: 28),
              
              // ─────────────────────────────────────────────────────────────────
              // 4. MEDICATIONS
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Medications",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -0.5),
                  ),
                  TextButton(
                    onPressed: () => context.push(RouteNames.patientPrescriptions), 
                    child: const Text('View All', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const DailyMedicationSchedule(),
              const SizedBox(height: 28),
              
              // ─────────────────────────────────────────────────────────────────
              // 5. VITALS
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Patient Status",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -0.5),
                  ),
                  TextButton(
                    onPressed: () => context.push('/patient/vitals-history'), 
                    child: const Text('See All History', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const VitalsSummaryCard(),
              const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────────
              // 6. MANAGE HEALTH
              // ─────────────────────────────────────────────────────────────────
              const Text(
                'Manage Health',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -0.5),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildActionTile(
                    context,
                    title: 'My Rx',
                    subtitle: '${prescriptions.length} active prescriptions',
                    icon: Icons.add_box_outlined,
                    color: Colors.blueAccent,
                    bgColor: AppColors.softBlue,
                    onTap: () => context.push(RouteNames.patientPrescriptions),
                  ),
                  _buildActionTile(
                    context,
                    title: 'History',
                    subtitle: '${records.length} past records',
                    icon: Icons.stacked_line_chart_rounded,
                    color: Colors.redAccent,
                    bgColor: AppColors.softPink,
                    onTap: () => context.push(RouteNames.patientMedicalHistory),
                  ),
                  _buildActionTile(
                    context,
                    title: 'Messages',
                    subtitle: '${chats.length} chats',
                    icon: Icons.article_outlined,
                    color: Colors.indigo,
                    bgColor: AppColors.softPurple,
                    onTap: () => context.push('/chat-list'),
                  ),
                  _buildActionTile(
                    context,
                    title: 'Privacy',
                    subtitle: 'Data controls',
                    icon: Icons.star_border_rounded,
                    color: Colors.green,
                    bgColor: const Color(0xFFDCFCE7),
                    onTap: () => context.push(RouteNames.patientPrivacy),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ─────────────────────────────────────────────────────────────────
              // 7. MY DOCTORS
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "My Doctors",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain, letterSpacing: -0.5),
                  ),
                  TextButton(
                    onPressed: () {}, 
                    child: const Text('See All', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              _buildDoctorItem('Dr. Priya Sharma', 'Cardiologist · 12 yrs exp.', 'PS', const Color(0xFFE0E7FF), context),
              const SizedBox(height: 12),
              _buildDoctorItem('Dr. Rohan Verma', 'General Physician · 8 yrs exp.', 'RV', const Color(0xFFDCFCE7), context),
              
              const SizedBox(height: 100), 
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patient/book-appointment'),
        backgroundColor: const Color(0xFF6366F1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
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
              _buildNavItem(Icons.home_filled, 'Home', true, () => context.go(RouteNames.patientDashboard)),
              _buildNavItem(Icons.assignment_outlined, 'Records', false, () => context.push(RouteNames.patientMedicalHistory)),
              const SizedBox(width: 48), 
              _buildNavItem(Icons.person_outline_rounded, 'Profile', false, () => context.push(RouteNames.profile)),
              _buildNavItem(Icons.settings_outlined, 'Settings', false, () => context.push(RouteNames.patientPrivacy)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighFidelityEmergencyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(RouteNames.patientQrCode),
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
                ),
              ),
              Positioned(
                right: 20,
                top: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'EMERGENCY ID',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Access',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to generate your secure QR code',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), shape: BoxShape.circle)),
                          ],
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
    );
  }

  Widget _buildDoctorItem(String name, String subtitle, String initials, Color avatarColor, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarColor,
            child: Text(initials, style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textMain)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          InkWell(
            onTap: () => context.push('/chat-list'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text('Message', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
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
          Icon(icon, color: isActive ? const Color(0xFF6366F1) : AppColors.textLight, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF6366F1) : AppColors.textLight,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Color bgColor,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain, fontSize: 16, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSub, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}