import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/device_service.dart';
import '../../../../routing/screen_titles.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  final _deviceService = DeviceService.instance;
  List<RegisteredDevice> _devices = [];
  String? _currentDeviceId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.tokens.accent),
    );
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    try {
      final devices = await _deviceService.getUserDevices();
      final currentDeviceId = await _deviceService.getDeviceId();

      if (mounted) {
        setState(() {
          _devices = devices;
          _currentDeviceId = currentDeviceId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Failed to load devices: $e');
      }
    }
  }

  Future<void> _revokeDevice(RegisteredDevice device) async {
    final confirmed = await showConfirmSheet(
      context,
      icon: Iconsax.slash,
      title: 'Revoke Device',
      message:
          'Are you sure you want to revoke access for ${device.deviceName}?\n\n'
          'This device will need to log in again with email, password, and 2FA.',
      confirmLabel: 'Revoke',
      destructive: true,
    );

    if (confirmed) {
      try {
        await _deviceService.revokeDevice(device.deviceId);
        if (mounted) {
          _snack('Device revoked successfully');
          _loadDevices();
        }
      } catch (e) {
        if (mounted) _snack('Failed to revoke device: $e');
      }
    }
  }

  Future<void> _deleteDevice(RegisteredDevice device) async {
    final confirmed = await showConfirmSheet(
      context,
      icon: Iconsax.trash,
      title: 'Delete Device',
      message:
          'Are you sure you want to permanently delete ${device.deviceName}?\n\n'
          'This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (confirmed) {
      try {
        await _deviceService.deleteDevice(device.deviceId);
        if (mounted) {
          _snack('Device deleted successfully');
          _loadDevices();
        }
      } catch (e) {
        if (mounted) _snack('Failed to delete device: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CSScaffold(
      title: ScreenTitles.deviceManagement,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _devices.isEmpty
              ? _buildEmptyState()
              : _buildDeviceList(),
    );
  }

  Widget _buildEmptyState() {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.mobile, size: 80, color: t.skeleton),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Devices Registered',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Register this device to enable biometric login',
              style: TextStyle(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Info Card
        SquircleCard(
          radius: AppSpacing.squircleGrouped,
          color: t.tint,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.info_circle, color: t.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Security',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Manage devices that have access to your account. '
                'Revoke access for devices you no longer use.',
                style: TextStyle(fontSize: 14, color: t.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Device Count
        Text(
          '${_devices.length} ${_devices.length == 1 ? 'Device' : 'Devices'}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.md),

        // Device List
        ..._devices.map((device) => _buildDeviceCard(device)),
      ],
    );
  }

  Widget _buildDeviceCard(RegisteredDevice device) {
    final t = context.tokens;
    final isCurrentDevice = device.deviceId == _currentDeviceId;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SquircleCard(
        radius: AppSpacing.squircleGrouped,
        borderSide: BorderSide(
          color: isCurrentDevice ? t.accent : t.divider,
          width: isCurrentDevice ? 2 : 1,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Device Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: t.tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      device.platformIcon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.deviceName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              ),
                            ),
                          ),
                          if (isCurrentDevice)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: t.accent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'This Device',
                                style: TextStyle(
                                  color: t.accentOn,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.platform?.toUpperCase() ?? 'Unknown',
                        style: TextStyle(fontSize: 12, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Device Details
            _buildDetailRow(
              icon: Iconsax.finger_scan,
              label: 'Biometric',
              value: device.biometricEnabled ? 'Enabled' : 'Disabled',
              valueColor: device.biometricEnabled ? t.accent : t.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDetailRow(
              icon: Iconsax.clock,
              label: 'Last Used',
              value: device.lastUsedString,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDetailRow(
              icon: Iconsax.calendar_1,
              label: 'Registered',
              value: _formatDate(device.registeredAt),
            ),

            // Actions
            if (!isCurrentDevice) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _revokeDevice(device),
                      icon: const Icon(Iconsax.slash, size: 18),
                      label: const Text('Revoke'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.error,
                        side: BorderSide(color: t.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteDevice(device),
                      icon: const Icon(Iconsax.trash, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.error,
                        side: BorderSide(color: t.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 16, color: t.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 14, color: t.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? t.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${(difference.inDays / 30).floor()} months ago';
    }
  }
}
