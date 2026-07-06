import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../patient/providers/appointment_provider.dart';

class AppointmentListWidget extends ConsumerWidget {
  const AppointmentListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(appointmentsProvider);

    return appointmentsAsync.when(
      data: (appointments) {
        if (appointments.isEmpty) {
          return _buildEmptyState(context);
        }
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appointments.length > 2 ? 2 : appointments.length,
          itemBuilder: (context, index) {
            final appt = appointments[index];
            return _buildAppointmentCard(context, appt, index);
          },
        );
      },
      loading: () => const Column(
        children: [
          LoadingSkeleton(height: 88, radius: 20),
          SizedBox(height: 12),
          LoadingSkeleton(height: 88, radius: 20),
        ],
      ),
      error: (err, _) => Center(
        child: Text(
          'Error loading appointments: $err',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Iconsax.calendar_tick, size: 28, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            'No scheduled appointments',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(BuildContext context, dynamic appt, int index) {
    final day = DateFormat('dd').format(appt.startTime);
    final month = DateFormat('MMM').format(appt.startTime).toUpperCase();
    final doctorName = appt.doctor?.fullName ?? 'Dr. Priya Sharma';
    final specialization = appt.doctor?.specialization ?? 'Cardiologist';
    final hospital = appt.doctor?.hospitalName ?? 'AIIMS Delhi';

    // Theme aligned premium accent colors (Violet for index 0, Indigo for index 1, etc.)
    final isEven = index % 2 == 0;
    final boxBg = isEven ? const Color(0xFFF5F3FF) : const Color(0xFFEEF2FF); // Soft Violet vs Soft Indigo
    final accentColor = isEven ? const Color(0xFF8B5CF6) : const Color(0xFF6366F1); // Violet vs Indigo

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Elegant Date Badge
          Container(
            width: 50,
            height: 56,
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  month,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: accentColor.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Doctor & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doctorName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Specialty row
                Row(
                  children: [
                    Icon(Iconsax.activity, size: 11, color: const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        specialization,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Hospital row
                Row(
                  children: [
                    Icon(Iconsax.location, size: 11, color: const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        hospital,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Time Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.clock, size: 12, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  DateFormat('h:mm a').format(appt.startTime),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
