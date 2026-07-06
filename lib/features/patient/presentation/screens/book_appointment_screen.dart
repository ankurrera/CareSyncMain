import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/models/user_profile.dart';
import '../../providers/appointment_provider.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  UserProfile? _selectedDoctor;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(availableDoctorsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Book Appointment',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: const Color(0xFF111827),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECTION: SELECT DOCTOR ─────────────────────
                  _sectionLabel('SELECT DOCTOR'),
                  const SizedBox(height: 12),
                  doctorsAsync.when(
                    data: (doctors) => Column(
                      children: doctors.map((doctor) {
                        final isSelected = _selectedDoctor?.id == doctor.id;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedDoctor = doctor;
                            _selectedSlot = null;
                          }),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0D0D0D)
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0D0D0D)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      doctor.fullName.isNotEmpty
                                          ? doctor.fullName[0].toUpperCase()
                                          : 'D',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF374151),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dr. ${doctor.fullName}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'General Practitioner',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: const Color(0xFF9CA3AF),
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
                                    color: isSelected
                                        ? const Color(0xFF0D0D0D)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0D0D0D)
                                          : const Color(0xFFD1D5DB),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check_rounded,
                                          size: 13, color: Colors.white)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (err, _) => Text('Error: $err',
                        style: GoogleFonts.plusJakartaSans()),
                  ),

                  if (_selectedDoctor != null) ...[
                    const SizedBox(height: 28),
                    // ── SECTION: SELECT DATE ─────────────────────
                    _sectionLabel('SELECT DATE'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF0D0D0D),
                            onPrimary: Colors.white,
                            onSurface: Color(0xFF111827),
                          ),
                        ),
                        child: CalendarDatePicker(
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
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
                    const SizedBox(height: 110),
                  ],
                ],
              ),
            ),
          ),

          // ── STICKY CONFIRM BUTTON ───────────────────────────────
          if (_selectedDoctor != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: GestureDetector(
                onTap: _selectedSlot != null ? _confirmBooking : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    color: _selectedSlot != null
                        ? const Color(0xFF0D0D0D)
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'CONFIRM BOOKING',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: _selectedSlot != null
                          ? Colors.white
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF374151),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTimeSlots() {
    if (_selectedDoctor == null) return const SizedBox.shrink();

    final availabilityAsync =
        ref.watch(doctorAvailabilityProvider(_selectedDoctor!.id));

    return availabilityAsync.when(
      data: (availabilities) {
        final supabaseDay = _selectedDate.weekday % 7;
        final dayAvailability =
            availabilities.where((a) => a.dayOfWeek == supabaseDay).toList();

        if (dayAvailability.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 28, color: Color(0xFFD1D5DB)),
                const SizedBox(height: 10),
                Text(
                  'No slots available on this day',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF9CA3AF),
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
            slots.add(DateFormat('hh:mm a').format(current));
            current = current.add(const Duration(minutes: 30));
          }
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
            // Split into time and am/pm
            final parts = slot.split(' ');
            final time = parts[0];
            final period = parts.length > 1 ? parts[1] : '';
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0D0D0D) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0D0D0D)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white : const Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      period,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.7)
                            : const Color(0xFF9CA3AF),
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
      },
      loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2)),
      error: (err, _) =>
          Text('Error: $err', style: GoogleFonts.plusJakartaSans()),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedDoctor == null || _selectedSlot == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
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
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        hour, minute,
      );

      await ref.read(appointmentsProvider.notifier).book(
        doctorId: _selectedDoctor!.id,
        startTime: startTime,
      );

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Booking Confirmed',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Appointment with Dr. ${_selectedDoctor!.fullName}\n${DateFormat('MMM d, yyyy · hh:mm a').format(startTime)}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'DONE',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
