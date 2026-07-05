import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/adaptive_card_container.dart';
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
            return _buildAppointmentTile(context, appt, index);
          },
        );
      },
      loading: () => const Column(
        children: [
          LoadingSkeleton(height: 76, radius: 20),
          SizedBox(height: 12),
          LoadingSkeleton(height: 76, radius: 20),
        ],
      ),
      error: (err, _) => Center(child: Text('Error loading appointments: $err', style: GoogleFonts.plusJakartaSans())),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded, size: 28, color: Color(0xFF94A3B8)),
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

  Widget _buildAppointmentTile(BuildContext context, dynamic appt, int index) {
    final day = DateFormat('dd').format(appt.startTime);
    final month = DateFormat('MMM').format(appt.startTime).toUpperCase();
    final doctorName = appt.doctor?.fullName ?? 'Dr. Priya Sharma';
    final specialization = appt.doctor?.specialization ?? 'Cardiologist';
    final hospital = appt.doctor?.hospitalName ?? 'AIIMS Delhi'; 

    // Colors aligned to visual guidelines
    final isPurple = index % 2 == 0;
    final boxBg = isPurple ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4); 
    final accentColor = isPurple ? const Color(0xFF6366F1) : const Color(0xFF22C55E); 

    return AdaptiveCardContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day,
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
                ),
                Text(
                  month,
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF121212), fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '$specialization • $hospital',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              DateFormat('h:mm\na').format(appt.startTime).toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}
