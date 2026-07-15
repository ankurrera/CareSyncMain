import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/emergency_access_service.dart';
import '../../../../routing/screen_titles.dart';

/// Screen for requesting emergency "break glass" access to patient records
class EmergencyAccessScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const EmergencyAccessScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<EmergencyAccessScreen> createState() =>
      _EmergencyAccessScreenState();
}

class _EmergencyAccessScreenState extends ConsumerState<EmergencyAccessScreen> {
  String? _selectedReason;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  final List<String> _emergencyReasons = [
    'Life-threatening emergency',
    'Critical care required',
    'Patient unconscious',
    'Severe allergic reaction',
    'Cardiac emergency',
    'Neurological emergency',
    'Trauma/accident',
    'Other critical situation',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _requestAccess() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a reason for emergency access'),
          backgroundColor: context.tokens.accent,
        ),
      );
      return;
    }

    final confirmed = await showConfirmSheet(
      context,
      icon: Iconsax.warning_2,
      title: 'Confirm Emergency Access',
      message:
          'You are requesting emergency "break glass" access to patient records.\n\n'
          'Patient: ${widget.patientName}\n'
          'Reason: $_selectedReason\n'
          'Duration: 15 minutes\n\n'
          'This action will be logged and the patient will be notified.',
      confirmLabel: 'Confirm & Proceed',
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final accessId = await EmergencyAccessService.instance
          .requestEmergencyAccess(
            patientId: widget.patientId,
            reason: _selectedReason!,
            additionalNotes:
                _notesController.text.trim().isNotEmpty
                    ? _notesController.text.trim()
                    : null,
          );

      if (accessId != null && mounted) {
        await EmergencyAccessService.instance.notifyPatient(
          widget.patientId,
          accessId,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Emergency access granted for 15 minutes'),
            backgroundColor: context.tokens.accent,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop(true);
      }
    } on EmergencyAccessException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return CSScaffold(
      title: ScreenTitles.patientEmergency,
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Warning banner
            SquircleCard(
              radius: AppSpacing.squircleGrouped,
              color: t.error.withValues(alpha: 0.08),
              borderSide: BorderSide(color: t.error.withValues(alpha: 0.3)),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconsax.warning_2, color: t.error, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency "Break Glass" Access',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This feature is for life-threatening emergencies only. All access is logged and audited.',
                          style: TextStyle(fontSize: 14, color: t.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Patient info
            _label('Patient Information'),
            const SizedBox(height: 12),
            SquircleCard(
              radius: AppSpacing.squircleGrouped,
              borderSide: BorderSide(color: t.divider),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: t.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Iconsax.user, color: t.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          'ID: ${widget.patientId.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 13,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Reason selection
            _label('Emergency Reason'),
            const SizedBox(height: 8),
            Text(
              'Select the reason for emergency access',
              style: TextStyle(fontSize: 14, color: t.textSecondary),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(
                hintText: 'Select reason',
                prefixIcon: Icon(Iconsax.warning_2),
              ),
              items:
                  _emergencyReasons.map((reason) {
                    return DropdownMenuItem(value: reason, child: Text(reason));
                  }).toList(),
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a reason';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            // Additional notes
            _label('Additional Notes (Optional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Provide additional context...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            // Access details
            SquircleCard(
              radius: AppSpacing.squircleGrouped,
              color: t.tint,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.info_circle, color: t.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Access Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(Iconsax.clock, 'Duration', '15 minutes'),
                  _buildDetailRow(
                    Iconsax.finger_scan,
                    'Authentication',
                    'Biometric required',
                  ),
                  _buildDetailRow(
                    Iconsax.document_text,
                    'Audit',
                    'Fully logged',
                  ),
                  _buildDetailRow(
                    Iconsax.notification,
                    'Patient',
                    'Will be notified',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Request button
            CSDestructiveButton(
              label:
                  _isLoading
                      ? 'Requesting Access...'
                      : 'Request Emergency Access',
              onPressed: _isLoading ? null : _requestAccess,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: context.tokens.textPrimary,
    ),
  );

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: t.accent),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13, color: t.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
