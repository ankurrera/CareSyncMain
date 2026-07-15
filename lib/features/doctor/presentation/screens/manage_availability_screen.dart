import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/logging/app_logger.dart';

import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/appointment_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../patient/providers/appointment_provider.dart';
import '../../../../routing/screen_titles.dart';

class ManageAvailabilityScreen extends ConsumerStatefulWidget {
  const ManageAvailabilityScreen({super.key});

  @override
  ConsumerState<ManageAvailabilityScreen> createState() =>
      _ManageAvailabilityScreenState();
}

class _ManageAvailabilityScreenState
    extends ConsumerState<ManageAvailabilityScreen> {
  final Map<int, List<TimeOfDay>> _availability = {
    0: [],
    1: [],
    2: [],
    3: [],
    4: [],
    5: [],
    6: [],
  };
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAvailability();
  }

  Future<void> _loadCurrentAvailability() async {
    setState(() => _isLoading = true);
    final doctorId = SupabaseService.instance.currentUserId;
    if (doctorId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final current = await ref.read(
        doctorAvailabilityProvider(doctorId).future,
      );
      if (current.isNotEmpty) {
        setState(() {
          for (var slot in current) {
            final timeParts = slot.startTime.split(':');
            final time = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );
            if (!_availability[slot.dayOfWeek]!.contains(time)) {
              _availability[slot.dayOfWeek]?.add(time);
            }
          }
          // Sort slots for each day
          for (var i = 0; i < 7; i++) {
            _availability[i]!.sort((a, b) => a.hour.compareTo(b.hour));
          }
        });
      }
    } catch (e) {
      AppLogger.warning(
        '[DOC] Error loading availability',
        category: LogCategory.database,
        error: e,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return CSScaffold(
      title: ScreenTitles.doctorAvailability,
      actions: [
        TextButton(
          onPressed: _saveAvailability,
          child: Text(
            'SAVE',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: t.accent,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.accent,
                ),
              )
              : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final dayName = _getDayName(index);
                  final slots = _availability[index]!;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SquircleCard(
                      radius: AppSpacing.squircleGrouped,
                      borderSide: BorderSide(color: t.divider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: t.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _addSlot(index),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: t.tint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Iconsax.add,
                                    color: t.accent,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (slots.isEmpty)
                            Text(
                              'Unavailable',
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  slots.map((slot) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: t.scaffold,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: t.divider),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            slot.format(context),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: t.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap:
                                                () => setState(
                                                  () => slots.remove(slot),
                                                ),
                                            child: Icon(
                                              Iconsax.close_circle,
                                              color: t.textSecondary,
                                              size: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  String _getDayName(int index) {
    return [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ][index];
  }

  Future<void> _addSlot(int dayIndex) async {
    final t = context.tokens;
    TimeOfDay fromTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay uptoTime = const TimeOfDay(hour: 17, minute: 0);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final startDouble = fromTime.hour + fromTime.minute / 60.0;
            final endDouble = uptoTime.hour + uptoTime.minute / 60.0;
            final isValid = endDouble > startDouble;

            List<TimeOfDay> generated = [];
            if (isValid) {
              var current = fromTime;
              while (true) {
                generated.add(current);
                var nextHour = current.hour + 1;
                if (nextHour >= 24) break;
                final nextTime = TimeOfDay(
                  hour: nextHour,
                  minute: current.minute,
                );
                final nextDouble = nextTime.hour + nextTime.minute / 60.0;
                if (nextDouble + 1.0 > endDouble + 0.01) {
                  break;
                }
                current = nextTime;
              }
            }

            final slotCount = generated.length;

            return Container(
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                top: 10,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: t.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Define Availability Frame',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: t.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a range to auto-generate hourly timeslots.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: fromTime,
                            );
                            if (time != null) {
                              setModalState(() => fromTime = time);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: t.scaffold,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FROM',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: t.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      fromTime.format(context),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    Icon(
                                      Iconsax.clock,
                                      size: 16,
                                      color: t.accent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: uptoTime,
                            );
                            if (time != null) {
                              setModalState(() => uptoTime = time);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: t.scaffold,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: t.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UPTO',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: t.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      uptoTime.format(context),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    Icon(
                                      Iconsax.clock,
                                      size: 16,
                                      color: t.accent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isValid
                              ? t.accent.withValues(alpha: 0.06)
                              : t.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isValid
                                ? t.accent.withValues(alpha: 0.2)
                                : t.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isValid ? Iconsax.info_circle : Iconsax.warning_2,
                          color: isValid ? t.accent : t.error,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isValid
                                ? 'Generates $slotCount hourly slot${slotCount == 1 ? '' : 's'} for this day.'
                                : 'Start time must be before end time.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isValid ? t.textPrimary : t.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              isValid
                                  ? () {
                                    setState(() {
                                      for (var slot in generated) {
                                        if (!_availability[dayIndex]!.contains(
                                          slot,
                                        )) {
                                          _availability[dayIndex]!.add(slot);
                                        }
                                      }
                                      _availability[dayIndex]!.sort(
                                        (a, b) => a.hour.compareTo(b.hour),
                                      );
                                    });
                                    Navigator.pop(context);
                                  }
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: t.divider,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Generate Slots',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAvailability() async {
    final doctorId = SupabaseService.instance.currentUserId;
    if (doctorId == null) return;

    setState(() => _isLoading = true);

    // Generate UPSERT data for Supabase
    final data = <Map<String, dynamic>>[];
    _availability.forEach((day, slots) {
      for (var slot in slots) {
        data.add({
          'day_of_week': day,
          'start_time':
              '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}:00',
          'end_time':
              '${(slot.hour + 1).toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}:00',
          'is_active': true,
        });
      }
    });

    try {
      // 1. Delete old slots to sync deletions
      await SupabaseService.instance.client
          .from('doctor_availability')
          .delete()
          .eq('doctor_id', doctorId);

      // 2. Insert new slots list
      if (data.isNotEmpty) {
        await ref.read(appointmentServiceProvider).setAvailability(data);
      }

      // 3. Sync riverpod cache
      ref.invalidate(doctorAvailabilityProvider(doctorId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Availability slots updated successfully!'),
            backgroundColor: context.tokens.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving availability: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
