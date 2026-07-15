import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/loading_skeleton.dart';
import '../../../patient/providers/appointment_provider.dart';

class AppointmentListWidget extends ConsumerWidget {
  const AppointmentListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
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
            return _buildAppointmentCard(context, appt);
          },
        );
      },
      loading:
          () => const Column(
            children: [
              LoadingSkeleton(height: 88, radius: 20),
              SizedBox(height: 12),
              LoadingSkeleton(height: 88, radius: 20),
            ],
          ),
      error:
          (err, _) => Center(
            child: Text(
              'Error loading appointments: $err',
              style: TextStyle(color: t.error),
            ),
          ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              Iconsax.calendar_1,
              size: 28,
              color: t.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              'No scheduled appointments',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your upcoming doctor visits will appear here.',
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

  Widget _buildAppointmentCard(BuildContext context, dynamic appt) {
    final t = context.tokens;
    final day = DateFormat('dd').format(appt.startTime);
    final month = DateFormat('MMM').format(appt.startTime).toUpperCase();
    final doctorName = appt.doctor?.fullName ?? 'Dr. Priya Sharma';
    final specialization = appt.doctor?.specialization ?? 'Cardiologist';
    final hospital = appt.doctor?.hospitalName ?? 'AIIMS Delhi';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(color: t.divider, width: 1.5),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date Badge
            Container(
              width: 50,
              height: 56,
              decoration: BoxDecoration(
                color: t.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t.accent,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: t.accent.withValues(alpha: 0.7),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Iconsax.activity, size: 11, color: t.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          specialization,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Iconsax.location, size: 11, color: t.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hospital,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: t.textSecondary,
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
                color: t.tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.clock, size: 12, color: t.accent),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('h:mm a').format(appt.startTime),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: t.accent,
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
}
