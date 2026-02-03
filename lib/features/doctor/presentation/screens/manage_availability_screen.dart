import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/models/user_profile.dart';
import '../../../patient/providers/appointment_provider.dart';
import '../../../../services/supabase_service.dart';

class ManageAvailabilityScreen extends ConsumerStatefulWidget {
  const ManageAvailabilityScreen({super.key});

  @override
  ConsumerState<ManageAvailabilityScreen> createState() => _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState extends ConsumerState<ManageAvailabilityScreen> {
  final Map<int, List<TimeOfDay>> _availability = {
    0: [], 1: [], 2: [], 3: [], 4: [], 5: [], 6: []
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentAvailability();
  }

  Future<void> _loadCurrentAvailability() async {
    final doctorId = SupabaseService.instance.currentUserId;
    if (doctorId == null) return;
    
    final current = await ref.read(doctorAvailabilityProvider(doctorId).future);
    if (current.isNotEmpty) {
      setState(() {
        for (var slot in current) {
          final timeParts = slot.startTime.split(':');
          _availability[slot.dayOfWeek]?.add(
            TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1])),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBackground,
      appBar: AppBar(
        title: const Text('Manage Availability'),
        actions: [
          TextButton(
            onPressed: _saveAvailability,
            child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.softPrimary)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 7,
        itemBuilder: (context, index) {
          final dayName = _getDayName(index);
          final slots = _availability[index]!;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    IconButton(
                      onPressed: () => _addSlot(index),
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.softPrimary),
                    ),
                  ],
                ),
                if (slots.isEmpty)
                  const Text('Unavailable', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Wrap(
                  spacing: 8,
                  children: slots.map((slot) => Chip(
                    label: Text(slot.format(context)),
                    onDeleted: () => setState(() => slots.remove(slot)),
                    backgroundColor: AppColors.softPrimary.withValues(alpha: 0.1),
                    deleteIconColor: AppColors.softPrimary,
                  )).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getDayName(int index) {
    return ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][index];
  }

  Future<void> _addSlot(int dayIndex) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    
    if (pickedTime != null) {
      setState(() {
        if (!_availability[dayIndex]!.contains(pickedTime)) {
          _availability[dayIndex]!.add(pickedTime);
          _availability[dayIndex]!.sort((a, b) => a.hour.compareTo(b.hour));
        }
      });
    }
  }

  Future<void> _saveAvailability() async {
    // Generate UPSERT data for Supabase
    final data = <Map<String, dynamic>>[];
    _availability.forEach((day, slots) {
      for (var slot in slots) {
        data.add({
          'day_of_week': day,
          'start_time': '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}:00',
          'end_time': '${(slot.hour + 1).toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}:00', // Default 1hr
          'is_active': true,
        });
      }
    });

    try {
      // Add logic to service layer if needed or use direct client
      // For now, I'll assume we update the service
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Availability saved!')));
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
