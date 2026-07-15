import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/logging/app_logger.dart';

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/user_profile.dart';
import '../../../../routing/screen_titles.dart';

// Provider for doctor signature status
final doctorSignatureProvider = FutureProvider<String?>((ref) async {
  return await SecureStorageService.instance.getDoctorSignature();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final profileAsync = ref.watch(currentProfileProvider);
    final kycAsync = ref.watch(kycStatusProvider);

    return CSScaffold(
      title: ScreenTitles.profile,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: profileAsync.when(
          loading:
              () => Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: CircularProgressIndicator(color: t.accent),
                ),
              ),
          error:
              (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Text(
                    'Error loading profile: $err',
                    style: TextStyle(color: t.error),
                  ),
                ),
              ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Text(
                    "Profile not found",
                    style: TextStyle(color: t.textSecondary),
                  ),
                ),
              );
            }

            final isVerified =
                kycAsync.valueOrNull?.status == KYCStatus.verified;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Center Section
                Center(
                  child: Column(
                    children: [
                      _buildAvatar(context, profile),
                      const SizedBox(height: 16),
                      Text(
                        profile.fullName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildVerificationBadge(context, isVerified),
                      const SizedBox(height: 16),

                      if (profile.isPatient) ...[
                        _buildMiniStatItem(
                          context,
                          label: 'Connected Devices',
                          value: '2',
                          icon: Iconsax.mobile,
                          onTap:
                              () => context.push(RouteNames.deviceManagement),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ],
                  ),
                ),

                if (profile.isDoctor) ...[
                  const SizedBox(height: 12),
                  _buildDoctorDetailsCard(context, ref, profile),
                  const SizedBox(height: 28),
                ],

                if (profile.isPharmacist) ...[
                  const SizedBox(height: 12),
                  _buildPharmacistDetailsCard(context, ref, profile),
                  const SizedBox(height: 28),
                ],

                Text(
                  'Account Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  borderSide: BorderSide(color: t.divider),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (profile.isPatient) ...[
                        _buildSettingsTile(
                          context,
                          icon: Iconsax.security_safe,
                          title: 'Privacy & Security Settings',
                          onTap: () => context.push(RouteNames.patientPrivacy),
                        ),
                      ],
                      _buildSettingsTile(
                        context,
                        icon: Iconsax.moon,
                        title: 'Appearance',
                        onTap: () => _showThemePicker(context, ref),
                      ),
                      _buildSettingsTile(
                        context,
                        icon: Iconsax.lock,
                        title: 'Change Password',
                        onTap: () {},
                      ),
                      _buildSettingsTile(
                        context,
                        icon: Iconsax.logout,
                        title: 'Sign Out',
                        isDestructive: true,
                        onTap: () async {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .signOut();
                          if (context.mounted) {
                            context.go(RouteNames.roleSelection);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(themeModeProvider);
    showAppSheet(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        final textTheme = Theme.of(ctx).textTheme;
        Widget option(String label, IconData icon, ThemeMode mode) {
          final selected = mode == current;
          return ListTile(
            leading: Icon(icon, color: selected ? t.accent : t.textPrimary),
            title: Text(label, style: textTheme.titleMedium),
            trailing: selected ? Icon(Icons.check, color: t.accent) : null,
            onTap: () {
              ref.read(themeModeProvider.notifier).setMode(mode);
              Navigator.of(ctx).pop();
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Appearance', style: t.sheetTitle),
              ),
              option('System', Iconsax.mobile, ThemeMode.system),
              option('Light', Iconsax.sun_1, ThemeMode.light),
              option('Dark', Iconsax.moon, ThemeMode.dark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerificationBadge(BuildContext context, bool isVerified) {
    final t = context.tokens;
    // Verified = accent (brand positive); unverified = error (needs action).
    final color = isVerified ? t.accent : t.error;
    return GestureDetector(
      onTap: isVerified ? null : () => context.push(RouteNames.kycVerification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVerified ? Iconsax.verify : Iconsax.warning_2,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              isVerified ? 'VERIFIED ID' : 'UNVERIFIED (COMPLETE KYC)',
              style: t.monoMeta.copyWith(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: t.accent),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: t.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorDetailsCard(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final t = context.tokens;
    final signatureAsync = ref.watch(doctorSignatureProvider);

    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildSettingsTile(
            context,
            icon: Iconsax.briefcase,
            title: 'Specialization: ${profile.specialization ?? 'Not set'}',
          ),
          _buildSettingsTile(
            context,
            icon: Iconsax.teacher,
            title: 'Workplace: ${profile.hospitalName ?? 'Not set'}',
            onTap: () => _showEditDoctorProfile(context, ref, profile),
          ),
          if (profile.medicalRegNumber != null)
            _buildSettingsTile(
              context,
              icon: Iconsax.card,
              title: 'Reg. Number: ${profile.medicalRegNumber!}',
            ),
          _buildSettingsTile(
            context,
            icon: Iconsax.edit_2,
            title:
                signatureAsync.valueOrNull != null
                    ? 'Digital Signature: Enrolled'
                    : 'Digital Signature: Not Set',
            onTap: () => _showSignaturePadSheet(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacistDetailsCard(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildSettingsTile(
            context,
            icon: Iconsax.briefcase,
            title: 'Pharmacy Name: ${profile.pharmacyName ?? 'Not set'}',
            onTap: () => _showEditPharmacistProfile(context, ref, profile),
          ),
          _buildSettingsTile(
            context,
            icon: Iconsax.location,
            title: 'Pharmacy Address: ${profile.pharmacyAddress ?? 'Not set'}',
            onTap: () => _showEditPharmacistProfile(context, ref, profile),
          ),
          if (profile.licenseNumber != null)
            _buildSettingsTile(
              context,
              icon: Iconsax.card,
              title: 'License Number: ${profile.licenseNumber!}',
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserProfile profile) {
    final t = context.tokens;
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.card,
        border: Border.all(color: t.divider, width: 2),
        image:
            profile.avatarUrl != null
                ? DecorationImage(
                  image: NetworkImage(profile.avatarUrl!),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child:
          profile.avatarUrl == null
              ? Icon(Iconsax.user, size: 36, color: t.textSecondary)
              : null,
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final t = context.tokens;
    final color = isDestructive ? t.error : t.textPrimary;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isDestructive ? t.error.withValues(alpha: 0.1) : t.scaffold,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          trailing:
              onTap != null
                  ? Icon(
                    Icons.chevron_right_rounded,
                    color: t.textSecondary,
                    size: 18,
                  )
                  : null,
        ),
        if (!isDestructive) Divider(height: 1, indent: 60, color: t.divider),
      ],
    );
  }

  void _showEditDoctorProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final hospitalController = TextEditingController(
      text: profile.hospitalName,
    );

    showAppSheet<void>(
      context,
      builder: (sheetCtx) {
        final t = sheetCtx.tokens;
        bool isLoading = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit Workplace',
                    textAlign: TextAlign.center,
                    style: t.sheetTitle,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: hospitalController,
                    style: TextStyle(fontSize: 14, color: t.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Hospital / Clinic Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: profile.specialization,
                    readOnly: true,
                    style: TextStyle(fontSize: 14, color: t.textSecondary),
                    decoration: InputDecoration(
                      labelText: 'Specialization (Locked)',
                      prefixIcon: const Icon(Iconsax.lock, size: 16),
                      filled: true,
                      fillColor: t.scaffold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CSTwoButtonRow(
                    cancelLabel: 'Cancel',
                    confirmLabel: isLoading ? 'Saving...' : 'Save Details',
                    onCancel: () => Navigator.pop(sheetCtx),
                    onConfirm:
                        isLoading
                            ? null
                            : () async {
                              if (hospitalController.text.trim().isEmpty) {
                                return;
                              }
                              setSheetState(() => isLoading = true);
                              try {
                                await SupabaseService.instance.upsertProfile({
                                  'hospital_clinic_name':
                                      hospitalController.text.trim(),
                                });
                                ref.invalidate(currentProfileProvider);
                                if (sheetCtx.mounted) {
                                  Navigator.pop(sheetCtx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Workplace profile updated successfully',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (sheetCtx.mounted) {
                                  setSheetState(() => isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: t.error,
                                    ),
                                  );
                                }
                              }
                            },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPharmacistProfile(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    final nameController = TextEditingController(text: profile.pharmacyName);
    final addressController = TextEditingController(
      text: profile.pharmacyAddress,
    );

    showAppSheet<void>(
      context,
      builder: (sheetCtx) {
        final t = sheetCtx.tokens;
        bool isLoading = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Pharmacy Profile',
                      textAlign: TextAlign.center,
                      style: t.sheetTitle,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(fontSize: 14, color: t.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Pharmacy Name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      style: TextStyle(fontSize: 14, color: t.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Pharmacy Address',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: profile.licenseNumber,
                      readOnly: true,
                      style: TextStyle(fontSize: 14, color: t.textSecondary),
                      decoration: InputDecoration(
                        labelText: 'License Number (Locked)',
                        prefixIcon: const Icon(Iconsax.lock, size: 16),
                        filled: true,
                        fillColor: t.scaffold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CSTwoButtonRow(
                      cancelLabel: 'Cancel',
                      confirmLabel: isLoading ? 'Saving...' : 'Save Details',
                      onCancel: () => Navigator.pop(sheetCtx),
                      onConfirm:
                          isLoading
                              ? null
                              : () async {
                                if (nameController.text.trim().isEmpty ||
                                    addressController.text.trim().isEmpty) {
                                  return;
                                }
                                setSheetState(() => isLoading = true);
                                try {
                                  await SupabaseService.instance.upsertProfile({
                                    'pharmacy_name': nameController.text.trim(),
                                    'pharmacy_address':
                                        addressController.text.trim(),
                                    'role': 'pharmacist',
                                  });
                                  ref.invalidate(currentProfileProvider);
                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Pharmacy profile updated successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: t.error,
                                      ),
                                    );
                                  }
                                }
                              },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSignaturePadSheet(BuildContext context, WidgetRef ref) {
    showAppSheet<void>(context, builder: (ctx) => _SignatureSheet(ref: ref));
  }
}

class _SignatureSheet extends StatefulWidget {
  final WidgetRef ref;
  const _SignatureSheet({required this.ref});

  @override
  State<_SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<_SignatureSheet> {
  final List<Offset?> _points = [];
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _save() async {
    if (_points.where((p) => p != null).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please draw your signature first'),
          backgroundColor: context.tokens.accent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final base64String = base64Encode(bytes);
        final hash = sha256.convert(bytes).toString();

        await SecureStorageService.instance.setDoctorSignature(base64String);
        await SecureStorageService.instance.setDoctorSignatureHash(hash);

        final userId = SupabaseService.instance.currentUserId;
        if (userId != null) {
          await SupabaseService.instance.client
              .from('doctors')
              .update({
                'signature_base64': base64String,
                'signature_hash': hash,
              })
              .eq('user_id', userId);
        }

        widget.ref.invalidate(doctorSignatureProvider);
        widget.ref.invalidate(currentProfileProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Digital signature enrolled successfully'),
              backgroundColor: context.tokens.accent,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      AppLogger.error(
        'Error saving signature',
        category: LogCategory.database,
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Draw Signature',
            textAlign: TextAlign.center,
            style: t.sheetTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Draw your official prescription signature inside the box below.',
            style: TextStyle(fontSize: 11, color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            height: 180,
            width: 280,
            decoration: BoxDecoration(
              color: t.scaffold,
              border: Border.all(color: t.divider),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: _SignaturePainter(_points, t.textPrimary),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _points.clear();
                  });
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: t.error,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await SecureStorageService.instance.setDoctorSignature('');
                  await SecureStorageService.instance.setDoctorSignatureHash(
                    '',
                  );
                  final userId = SupabaseService.instance.currentUserId;
                  if (userId != null) {
                    try {
                      await SupabaseService.instance.client
                          .from('doctors')
                          .update({
                            'signature_base64': null,
                            'signature_hash': null,
                          })
                          .eq('user_id', userId);
                    } catch (e) {
                      AppLogger.error(
                        'Error removing signature from database',
                        category: LogCategory.database,
                        error: e,
                      );
                    }
                  }
                  widget.ref.invalidate(doctorSignatureProvider);
                  widget.ref.invalidate(currentProfileProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  'Reset/Remove',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: t.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CSTwoButtonRow(
            cancelLabel: 'Cancel',
            confirmLabel: _isSaving ? 'Saving...' : 'Save Stamp',
            onCancel: _isSaving ? null : () => Navigator.of(context).pop(),
            onConfirm: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  _SignaturePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint =
        Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
