import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../providers/health_sync_provider.dart';

class HealthTrackersSheet extends ConsumerStatefulWidget {
  const HealthTrackersSheet({super.key});

  @override
  ConsumerState<HealthTrackersSheet> createState() =>
      _HealthTrackersSheetState();
}

class _HealthTrackersSheetState extends ConsumerState<HealthTrackersSheet> {
  final List<Map<String, dynamic>> _trackers = [
    {
      'id': 'apple_health',
      'name': 'Apple HealthKit',
      'subtitle': 'iOS Native Health Ledger',
      'icon': Icons.apple_rounded,
      'color': const Color(0xFFFF2D55),
      'isOAuth': false,
    },
    {
      'id': 'google_fit',
      'name': 'Google Fit / Health Connect',
      'subtitle': 'Android Shared Vitals Storage',
      'icon': Icons.fitbit_rounded,
      'color': const Color(0xFF34A853),
      'isOAuth': false,
    },
    {
      'id': 'whoop',
      'name': 'Whoop Strap 4.0',
      'subtitle': 'Live Heart Rate Variability & Sleep',
      'icon': Iconsax.activity,
      'color': const Color(0xFF121212),
      'isOAuth': true,
    },
    {
      'id': 'fitbit',
      'name': 'Fitbit Tracker',
      'subtitle': 'Activity, Sleep and Daily HR logs',
      'icon': Iconsax.repeat,
      'color': const Color(0xFF00B0B9),
      'isOAuth': true,
    },
    {
      'id': 'garmin',
      'name': 'Garmin Connect',
      'subtitle': 'Fitness Tracking & Bio-Metrics',
      'icon': Icons.watch_rounded,
      'color': const Color(0xFF007ACC),
      'isOAuth': true,
    },
  ];

  Future<void> _handleConnect(
    String trackerId,
    String trackerName,
    bool isOAuth,
  ) async {
    final notifier = ref.read(healthSyncProvider.notifier);
    if (isOAuth) {
      await notifier.connectOAuthSource(trackerId);
    } else {
      await notifier.connectPlatformSource(trackerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(healthSyncProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle indicator
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF4F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.activity,
                  color: Color(0xFFFF5200),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Tracker Integration',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF121212),
                      ),
                    ),
                    Text(
                      'Synchronize live fitband or wearable sensor streams',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (syncState.syncError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      syncState.syncError!,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (syncState.isSyncing) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF5200),
                    ),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Accessing SDK Wearable Link...',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: const Color(0xFF121212),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Establishing secure Health authorization',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Trackers list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _trackers.length,
              itemBuilder: (context, idx) {
                final tracker = _trackers[idx];
                final isConnected = syncState.connectedSources.contains(
                  tracker['id'],
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (tracker['color'] as Color).withValues(
                            alpha: 0.08,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          tracker['icon'] as IconData,
                          color: tracker['color'] as Color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tracker['name'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: const Color(0xFF121212),
                              ),
                            ),
                            Text(
                              tracker['subtitle'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isConnected)
                        ElevatedButton(
                          onPressed: () {
                            ref
                                .read(healthSyncProvider.notifier)
                                .disconnectSource(tracker['id'] as String);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Disconnected ${tracker['name']} sync.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEE2E2),
                            foregroundColor: const Color(0xFFEF4444),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Disconnect',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed:
                              () => _handleConnect(
                                tracker['id'] as String,
                                tracker['name'] as String,
                                tracker['isOAuth'] as bool,
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF121212),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Connect',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
