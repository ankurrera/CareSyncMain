import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Book Appointment',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF121212)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF121212)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Doctor',
              style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
            ),
            const SizedBox(height: 16),
            doctorsAsync.when(
              data: (doctors) => SizedBox(
                height: 124,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final isSelected = _selectedDoctor?.id == doctor.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDoctor = doctor),
                      child: Container(
                        width: 104,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFFF4F0) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFF5200) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isSelected ? const Color(0xFFFF5200) : const Color(0xFFF1F5F9),
                              child: Text(
                                doctor.fullName.isNotEmpty ? doctor.fullName[0].toUpperCase() : 'D',
                                style: GoogleFonts.plusJakartaSans(
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                doctor.fullName.split(' ').last,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF121212),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
              error: (err, _) => Text('Error loading doctors: $err', style: GoogleFonts.plusJakartaSans()),
            ),

            if (_selectedDoctor != null) ...[
              const SizedBox(height: 28),
              Text(
                'Select Date',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
              ),
              const SizedBox(height: 16),
              _buildDatePicker(),
              
              const SizedBox(height: 28),
              Text(
                'Available Slots',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
              ),
              const SizedBox(height: 16),
              _buildTimeSlots(),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _selectedSlot != null ? _confirmBooking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm Booking', 
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF5200),
            onPrimary: Colors.white,
            onSurface: Color(0xFF121212),
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
    );
  }

  Widget _buildTimeSlots() {
    if (_selectedDoctor == null) return const SizedBox.shrink();

    final availabilityAsync = ref.watch(doctorAvailabilityProvider(_selectedDoctor!.id));

    return availabilityAsync.when(
      data: (availabilities) {
        final supabaseDay = _selectedDate.weekday % 7;
        final dayAvailability = availabilities.where((a) => a.dayOfWeek == supabaseDay).toList();

        if (dayAvailability.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No availability on this day', 
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 13),
              ),
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

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: slots.map((slot) {
            final isSelected = _selectedSlot == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF5200) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFF5200) : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  slot,
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? Colors.white : const Color(0xFF121212),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
      error: (err, _) => Text('Error loading availability: $err', style: GoogleFonts.plusJakartaSans()),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedDoctor == null || _selectedSlot == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5200))),
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

      await ref.read(appointmentsProvider.notifier).book(
        doctorId: _selectedDoctor!.id,
        startTime: startTime,
      );

      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 10),
                Text(
                  'Booking Confirmed',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF121212)),
                ),
              ],
            ),
            content: Text(
              'Your appointment with ${_selectedDoctor!.fullName} is scheduled for ${DateFormat('MMM d, hh:mm a').format(startTime)}.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Pop success dialog
                  Navigator.pop(context); // Back to home
                },
                child: Text(
                  'Great!',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFFFF5200)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: $e', style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
