import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design/confirm_sheet.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../providers/patient_provider.dart';
import '../../../../routing/screen_titles.dart';

final patientSettingsProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return null;

  final result =
      await supabase
          .from('patients')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

  return result;
});

final publicPrescriptionsCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return 0;

  final patientResult =
      await supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

  if (patientResult == null) return 0;

  final result = await supabase
      .from('prescriptions')
      .select('id')
      .eq('patient_id', patientResult['id'])
      .eq('is_public', true);

  return result.length;
});

final publicConditionsCountProvider = FutureProvider<int>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return 0;

  final patientResult =
      await supabase
          .from('patients')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

  if (patientResult == null) return 0;

  final result = await supabase
      .from('medical_conditions')
      .select('id')
      .eq('patient_id', patientResult['id'])
      .eq('is_public', true);

  return result.length;
});

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final patientSettings = ref.watch(patientSettingsProvider);
    final publicPrescriptions = ref.watch(publicPrescriptionsCountProvider);
    final publicConditions = ref.watch(publicConditionsCountProvider);

    return CSScaffold(
      title: ScreenTitles.patientPrivacy,
      body: patientSettings.when(
        loading:
            () => Center(child: CircularProgressIndicator(color: t.accent)),
        error:
            (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.warning_2, size: 40, color: t.error),
                  const SizedBox(height: 16),
                  Text('Error: $error', style: TextStyle(color: t.textPrimary)),
                  TextButton(
                    onPressed: () => ref.invalidate(patientSettingsProvider),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        data: (patient) {
          final condCount = publicConditions.valueOrNull?.toString() ?? '0';
          final rxCount = publicPrescriptions.valueOrNull?.toString() ?? '0';

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  color: t.tint,
                  borderSide: BorderSide(
                    color: t.accent.withValues(alpha: 0.2),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.info_circle, color: t.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Control what information is visible when your emergency QR code is scanned by first responders.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency Data Summary
                _sectionTitle(context, 'Emergency Data Summary'),
                const SizedBox(height: 12),
                _buildSummaryCard(context, condCount, rxCount),
                const SizedBox(height: 24),

                // Profile Information
                _sectionTitle(context, 'Profile Information'),
                const SizedBox(height: 12),
                SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  borderSide: BorderSide(color: t.divider),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildSettingRow(
                        context,
                        icon: Iconsax.user,
                        title: 'Full Name',
                        subtitle: 'Always visible to first responders',
                        isPublic: true,
                        locked: true,
                      ),
                      Divider(height: 1, color: t.divider),
                      _buildSettingRow(
                        context,
                        icon: Iconsax.drop,
                        title: 'Blood Type',
                        subtitle:
                            (patient?['blood_type'] as String?) ?? 'Not set',
                        isPublic: true,
                        locked: true,
                        onEdit:
                            () => _showBloodTypeSheet(
                              context,
                              ref,
                              patient?['blood_type'],
                            ),
                      ),
                      Divider(height: 1, color: t.divider),
                      _buildSettingRow(
                        context,
                        icon: Iconsax.radar_2,
                        title: 'Emergency Contact',
                        subtitle:
                            patient?['emergency_contact'] != null
                                ? 'Contact registered'
                                : 'Not set',
                        isPublic: true,
                        locked: true,
                        onEdit:
                            () => _showEmergencyContactSheet(
                              context,
                              ref,
                              patient?['emergency_contact'],
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                _sectionTitle(context, 'Quick Actions'),
                const SizedBox(height: 12),
                SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  borderSide: BorderSide(color: t.divider),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildActionTile(
                        context,
                        icon: Iconsax.eye_slash,
                        title: 'Make All Conditions Private',
                        subtitle: 'Hide all medical conditions from QR',
                        onTap: () => _makeAllConditionsPrivate(context, ref),
                      ),
                      Divider(height: 1, color: t.divider),
                      _buildActionTile(
                        context,
                        icon: Iconsax.eye,
                        title: 'Make All Conditions Public',
                        subtitle: 'Show all medical conditions in QR',
                        onTap: () => _makeAllConditionsPublic(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger Zone
                _sectionTitle(context, 'Danger Zone', color: t.error),
                const SizedBox(height: 12),
                SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  borderSide: BorderSide(color: t.error.withValues(alpha: 0.3)),
                  padding: EdgeInsets.zero,
                  child: _buildActionTile(
                    context,
                    icon: Iconsax.barcode,
                    title: 'Regenerate QR Code',
                    subtitle: 'Old QR codes will stop working',
                    destructive: true,
                    onTap: () => _regenerateQrCode(context, ref),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, {Color? color}) {
    final t = context.tokens;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color ?? t.textPrimary,
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String conditions,
    String prescriptions,
  ) {
    final t = context.tokens;
    Widget item(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: t.accent, size: 18),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: t.monoMeta.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: t.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          item(Iconsax.activity, conditions, 'PUBLIC CONDITIONS'),
          Container(width: 1, height: 32, color: t.divider),
          item(Iconsax.document_text, prescriptions, 'PUBLIC PRESCRIPTIONS'),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPublic,
    bool locked = false,
    VoidCallback? onEdit,
  }) {
    final t = context.tokens;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
        child: Icon(icon, color: t.accent, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: t.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: t.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: Icon(Iconsax.edit_2, size: 14, color: t.accent),
              constraints: const BoxConstraints(),
              style: IconButton.styleFrom(
                backgroundColor: t.tint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
              ),
              onPressed: onEdit,
            ),
          if (onEdit != null) const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked
                      ? Iconsax.lock_1
                      : (isPublic ? Iconsax.eye : Iconsax.eye_slash),
                  size: 11,
                  color: t.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  isPublic ? 'Public' : 'Private',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final t = context.tokens;
    final accent = destructive ? t.error : t.accent;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accent, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: t.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: t.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Iconsax.arrow_right_3, color: t.textSecondary, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _showBloodTypeSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentType,
  ) async {
    final bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    final selected = await showAppSheet<String>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Blood Type', style: t.sheetTitle),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    bloodTypes.map((type) {
                      final isSelected = currentType == type;
                      return GestureDetector(
                        onTap: () => Navigator.pop(ctx, type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? t.accent : t.scaffold,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? t.accent : t.divider,
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? t.accentOn : t.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && context.mounted) {
      await _updatePatientField(context, ref, 'blood_type', selected);
    }
  }

  Future<void> _showEmergencyContactSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? current,
  ) async {
    final nameController = TextEditingController(text: current?['name']);
    final phoneController = TextEditingController(text: current?['phone']);
    final relationshipController = TextEditingController(
      text: current?['relationship'],
    );

    await showAppSheet<void>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        Widget field(
          String label,
          TextEditingController controller,
          String hint, {
          TextInputType? keyboard,
        }) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: t.monoMeta.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 9,
                color: t.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: keyboard,
              style: TextStyle(fontSize: 14, color: t.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: t.scaffold,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergency Contact', style: t.sheetTitle),
                const SizedBox(height: 20),
                field('CONTACT NAME', nameController, 'Enter contact name'),
                field(
                  'PHONE NUMBER',
                  phoneController,
                  'Enter phone number',
                  keyboard: TextInputType.phone,
                ),
                field(
                  'RELATIONSHIP',
                  relationshipController,
                  'e.g., Spouse, Parent',
                ),
                const SizedBox(height: 10),
                CSTwoButtonRow(
                  cancelLabel: 'Cancel',
                  confirmLabel: 'Save',
                  onCancel: () => Navigator.pop(ctx),
                  onConfirm: () async {
                    final contact = {
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'relationship': relationshipController.text.trim(),
                    };
                    Navigator.pop(ctx);
                    await _updatePatientField(
                      context,
                      ref,
                      'emergency_contact',
                      contact,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updatePatientField(
    BuildContext context,
    WidgetRef ref,
    String field,
    dynamic value,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      await supabase.from('patients').upsert({
        'user_id': userId,
        field: value,
      }, onConflict: 'user_id');

      ref.invalidate(patientSettingsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPrivate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirm = await showConfirmSheet(
      context,
      icon: Iconsax.eye_slash,
      title: 'Make All Private',
      message:
          'This will hide all your medical conditions from first responders scanning your QR code.',
      confirmLabel: 'Confirm',
    );

    if (!confirm) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final patientResult =
          await supabase
              .from('patients')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (patientResult == null) return;

      await supabase
          .from('medical_conditions')
          .update({'is_public': false})
          .eq('patient_id', patientResult['id']);

      ref.invalidate(publicConditionsCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All conditions are now private'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _makeAllConditionsPublic(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirm = await showConfirmSheet(
      context,
      icon: Iconsax.eye,
      title: 'Make All Public',
      message:
          'This will make all your medical conditions visible to first responders scanning your QR code.',
      confirmLabel: 'Confirm',
    );

    if (!confirm) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final patientResult =
          await supabase
              .from('patients')
              .select('id')
              .eq('user_id', userId)
              .maybeSingle();

      if (patientResult == null) return;

      await supabase
          .from('medical_conditions')
          .update({'is_public': true})
          .eq('patient_id', patientResult['id']);

      ref.invalidate(publicConditionsCountProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All conditions are now public'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _regenerateQrCode(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmSheet(
      context,
      icon: Iconsax.barcode,
      title: 'Regenerate QR Code',
      message:
          'This will create a new QR code and invalidate your old one. '
          'Any printed cards or stickers with the old QR code will stop working. '
          'Are you sure?',
      confirmLabel: 'Regenerate',
      destructive: true,
    );

    if (!confirm) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final newQrCodeId = const Uuid().v4();

      await supabase
          .from('patients')
          .update({'qr_code_id': newQrCodeId})
          .eq('user_id', userId);

      ref.invalidate(patientSettingsProvider);
      ref.invalidate(patientDataProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code regenerated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
