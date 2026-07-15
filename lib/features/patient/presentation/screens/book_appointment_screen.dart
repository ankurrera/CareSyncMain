import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../shared/models/user_profile.dart';
import '../../providers/appointment_provider.dart';
import '../../../shared/presentation/screens/notifications_screen.dart';
import '../../../../routing/screen_titles.dart';
import '../../../../services/connectivity_service.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  UserProfile? _selectedDoctor;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final doctorsAsync = ref.watch(availableDoctorsProvider);

    final connectivity = ref.watch(connectivityStatusProvider).valueOrNull;
    final isOffline = connectivity == ConnectivityStatus.offline;

    return CSScaffold(
      title: ScreenTitles.patientBookAppointment,
      bottomNavigationBar:
          _selectedDoctor != null
              ? Container(
                color: t.card,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: CSPrimaryButton(
                  label: isOffline ? 'Offline Mode' : 'Confirm Booking',
                  onPressed:
                      (isOffline || _selectedSlot == null)
                          ? null
                          : _confirmBooking,
                ),
              )
              : null,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECTION: SELECT DOCTOR ─────────────────────
            _sectionLabel('SELECT DOCTOR'),
            const SizedBox(height: 12),
            doctorsAsync.when(
              data:
                  (doctors) => Column(
                    children:
                        doctors.map((doctor) {
                          final isSelected = _selectedDoctor?.id == doctor.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SquircleCard(
                              radius: AppSpacing.squircleGrouped,
                              borderSide: BorderSide(
                                color: isSelected ? t.accent : t.divider,
                                width: isSelected ? 1.5 : 1,
                              ),
                              padding: const EdgeInsets.all(14),
                              onTap:
                                  () => setState(() {
                                    _selectedDoctor = doctor;
                                    _selectedSlot = null;
                                  }),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isSelected ? t.accent : t.tint,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        doctor.fullName.isNotEmpty
                                            ? doctor.fullName[0].toUpperCase()
                                            : 'D',
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? t.accentOn
                                                  : t.accent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dr. ${doctor.fullName}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: t.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'General Practitioner',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: t.textSecondary,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Check indicator
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          isSelected
                                              ? t.accent
                                              : Colors.transparent,
                                      border: Border.all(
                                        color:
                                            isSelected ? t.accent : t.divider,
                                        width: 1.5,
                                      ),
                                    ),
                                    child:
                                        isSelected
                                            ? Icon(
                                              Icons.check_rounded,
                                              size: 13,
                                              color: t.accentOn,
                                            )
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
              loading:
                  () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              error: (err, _) => Text('Error: $err'),
            ),

            if (_selectedDoctor != null) ...[
              const SizedBox(height: 28),
              // ── SECTION: SELECT DATE ─────────────────────
              _sectionLabel('SELECT DATE'),
              const SizedBox(height: 12),
              SquircleCard(
                radius: AppSpacing.squircleGrouped,
                borderSide: BorderSide(color: t.divider),
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: t.accent,
                      onPrimary: t.accentOn,
                    ),
                  ),
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    onDateChanged: (date) {
                      setState(() {
                        _selectedDate = date;
                        _selectedSlot = null;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // ── SECTION: TIME SLOTS ──────────────────────
              _sectionLabel('AVAILABLE SLOTS'),
              const SizedBox(height: 12),
              _buildTimeSlots(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    final t = context.tokens;
    return Text(
      text,
      style: t.monoSectionHeader.copyWith(
        color: t.textSecondary,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTimeSlots() {
    final t = context.tokens;
    if (_selectedDoctor == null) return const SizedBox.shrink();

    final availabilityAsync = ref.watch(
      doctorAvailabilityProvider(_selectedDoctor!.id),
    );
    final bookedAsync = ref.watch(
      bookedAppointmentsProvider(
        doctorId: _selectedDoctor!.id,
        date: _selectedDate,
      ),
    );

    if (availabilityAsync.isLoading || bookedAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
        ),
      );
    }

    if (availabilityAsync.hasError) {
      return Center(
        child: Text(
          'Error: ${availabilityAsync.error}',
          style: TextStyle(color: t.error),
        ),
      );
    }
    if (bookedAsync.hasError) {
      return Center(
        child: Text(
          'Error: ${bookedAsync.error}',
          style: TextStyle(color: t.error),
        ),
      );
    }

    final availabilities = availabilityAsync.value ?? [];
    final bookedAppointments = bookedAsync.value ?? [];

    final supabaseDay = _selectedDate.weekday % 7;
    final dayAvailability =
        availabilities.where((a) => a.dayOfWeek == supabaseDay).toList();

    if (dayAvailability.isEmpty) {
      return SquircleCard(
        radius: AppSpacing.squircleGrouped,
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 28,
              color: t.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              'No slots available on this day',
              style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final slots = <String>[];
    for (final avail in dayAvailability) {
      final start = DateFormat('HH:mm:ss').parse(avail.startTime);
      final end = DateFormat('HH:mm:ss').parse(avail.endTime);
      var current = DateTime(2000, 1, 1, start.hour, start.minute);
      final endTime = DateTime(2000, 1, 1, end.hour, end.minute);
      while (current.isBefore(endTime)) {
        final formattedSlot = DateFormat('hh:mm a').format(current);
        final isBooked = bookedAppointments.any(
          (b) =>
              b.status != 'cancelled' &&
              DateFormat('hh:mm a').format(b.startTime.toLocal()) ==
                  formattedSlot,
        );
        if (!isBooked) {
          slots.add(formattedSlot);
        }
        current = current.add(const Duration(minutes: 30));
      }
    }

    if (slots.isEmpty) {
      return SquircleCard(
        radius: AppSpacing.squircleGrouped,
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 28,
              color: t.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              'All slots booked for this day',
              style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.4,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = _selectedSlot == slot;
        final parts = slot.split(' ');
        final time = parts[0];
        final period = parts.length > 1 ? parts[1] : '';
        return GestureDetector(
          onTap: () => setState(() => _selectedSlot = slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? t.accent : t.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? t.accent : t.divider,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isSelected ? t.accentOn : t.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    color:
                        isSelected
                            ? t.accentOn.withValues(alpha: 0.7)
                            : t.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedDoctor == null || _selectedSlot == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );

    try {
      final timeParts = _selectedSlot!.split(' ');
      final hourMin = timeParts[0].split(':');
      var hour = int.parse(hourMin[0]);
      final minute = int.parse(hourMin[1]);

      if (timeParts[1] == 'PM' && hour < 12) hour += 12;
      if (timeParts[1] == 'AM' && hour == 12) hour = 0;

      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );

      await ref
          .read(appointmentsProvider.notifier)
          .book(doctorId: _selectedDoctor!.id, startTime: startTime);

      // Create a local notification for the patient
      ref
          .read(notificationsProvider.notifier)
          .addNotification(
            title: 'Appointment Scheduled',
            message:
                'Your appointment with Dr. ${_selectedDoctor!.fullName} is scheduled for ${DateFormat('MMM d, yyyy · hh:mm a').format(startTime)}.',
            type: 'reminder',
          );

      if (mounted) {
        Navigator.pop(context);
        await showAppSheet<void>(
          context,
          builder:
              (ctx) => AppSheetContent(
                icon: Iconsax.tick_circle,
                title: 'Booking Confirmed',
                message:
                    'Appointment with Dr. ${_selectedDoctor!.fullName}\n${DateFormat('MMM d, yyyy · hh:mm a').format(startTime)}',
                children: [
                  CSPrimaryButton(
                    label: 'Done',
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);

        String errorMessage = 'Booking failed: $e';
        if (e.toString().contains('23505') ||
            e.toString().contains('unique_active_doctor_appointment')) {
          errorMessage =
              'This slot was just booked by another patient. Please choose a different slot.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
