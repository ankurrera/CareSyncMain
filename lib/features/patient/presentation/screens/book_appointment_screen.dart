import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textMain,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Doctor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            doctorsAsync.when(
              data: (doctors) => SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final doctor = doctors[index];
                    final isSelected = _selectedDoctor?.id == doctor.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDoctor = doctor),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.softPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.softPrimary.withValues(alpha: 0.1),
                              child: Text(
                                doctor.fullName[0],
                                style: TextStyle(color: isSelected ? Colors.white : AppColors.softPrimary),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                doctor.fullName.split(' ').last,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textMain,
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading doctors: $err'),
            ),

            if (_selectedDoctor != null) ...[
              const SizedBox(height: 32),
              const Text(
                'Select Date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDatePicker(),
              
              const SizedBox(height: 32),
              const Text(
                'Available Slots',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTimeSlots(),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedSlot != null ? _confirmBooking : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.softPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
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
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
    );
  }

  Widget _buildTimeSlots() {
    if (_selectedDoctor == null) return const SizedBox.shrink();

    final availabilityAsync = ref.watch(doctorAvailabilityProvider(_selectedDoctor!.id));

    return availabilityAsync.when(
      data: (availabilities) {
        // Map Flutter weekday (1-7, Mon-Sun) to Supabase (0-6, Sun-Sat)
        final supabaseDay = _selectedDate.weekday % 7;
        final dayAvailability = availabilities.where((a) => a.dayOfWeek == supabaseDay).toList();

        if (dayAvailability.isEmpty) {
          return const Center(child: Text('No availability on this day', style: TextStyle(color: Colors.grey)));
        }

        // Generate slots
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
          spacing: 12,
          runSpacing: 12,
          children: slots.map((slot) {
            final isSelected = _selectedSlot == slot;
            return GestureDetector(
              onTap: () => setState(() => _selectedSlot = slot),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.softPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.softPrimary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textMain,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error loading availability: $err'),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedDoctor == null || _selectedSlot == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
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
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Booking Confirmed'),
              ],
            ),
            content: Text('Your appointment with ${_selectedDoctor!.fullName} is scheduled for ${DateFormat('MMM d, hh:mm a').format(startTime)}.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Pop success dialog
                  Navigator.pop(context); // Back to home
                },
                child: const Text('Great!'),
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
            content: Text('Booking failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
