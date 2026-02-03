import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
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
          physics: const NeverScrollableScrollPhysics(),
          itemCount: appointments.length > 2 ? 2 : appointments.length, // Show max 2 like mockup
          itemBuilder: (context, index) {
            final appt = appointments[index];
            return _buildAppointmentTile(context, appt, index);
          },
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      )),
      error: (err, _) => Text('Error: $err'),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No scheduled appointments', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(BuildContext context, dynamic appt, int index) {
    final day = DateFormat('dd').format(appt.startTime);
    final month = DateFormat('MMM').format(appt.startTime).toUpperCase();
    final time = DateFormat('h:mm\na').format(appt.startTime).replaceAll('\n', '\n'); 
    final doctorName = appt.doctor?.fullName ?? 'Dr. Priya Sharma';
    final specialization = appt.doctor?.specialization ?? 'Cardiologist';
    final hospital = appt.doctor?.hospitalName ?? 'AIIMS Delhi'; 

    // Colors from mockup
    final isPurple = index % 2 == 0;
    final boxBg = isPurple ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4); // Indigo vs Green bg
    final accentColor = isPurple ? const Color(0xFF6366F1) : const Color(0xFF22C55E); // Indigo vs Green accent

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          // Date Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accentColor),
                ),
                Text(
                  month,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accentColor.withValues(alpha: 0.7)),
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
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textMain, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '$specialization · $hospital',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSub, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              DateFormat('h:mm\na').format(appt.startTime).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accentColor, height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}
