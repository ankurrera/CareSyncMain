import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/kyc_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../../../routing/screen_titles.dart';

class QrCodeScreen extends ConsumerStatefulWidget {
  const QrCodeScreen({super.key});

  @override
  ConsumerState<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends ConsumerState<QrCodeScreen>
    with SingleTickerProviderStateMixin {
  bool _screenshotProtectionEnabled = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isCardFront = true;

  // Tilt physics variables
  double _targetTiltX = 0.0;
  double _targetTiltY = 0.0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isCardFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _isCardFront = !_isCardFront;
    });
  }

  void _updateTilt(Offset localPosition, double width, double height) {
    if (width <= 0 || height <= 0) return;

    final normX = (localPosition.dx / width) * 2 - 1;
    final normY = (localPosition.dy / height) * 2 - 1;

    final clampedX = normX.clamp(-1.0, 1.0);
    final clampedY = normY.clamp(-1.0, 1.0);

    const maxTilt = 0.2618;

    setState(() {
      _targetTiltX = -clampedY * maxTilt;
      _targetTiltY = clampedX * maxTilt;
    });
  }

  void _resetTilt() {
    setState(() {
      _targetTiltX = 0.0;
      _targetTiltY = 0.0;
    });
  }

  void _onAuthenticated() {
    if (Platform.isAndroid) {
      setState(() => _screenshotProtectionEnabled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final profileAsync = ref.watch(currentProfileProvider);
    final patientAsync = ref.watch(patientDataProvider);

    return BiometricGuard(
      reason: 'Authenticate to view your Medical ID',
      strictMode: false,
      onAuthenticated: _onAuthenticated,
      child: CSScaffold(
        title: ScreenTitles.patientQrCode,
        body: patientAsync.when(
          data: (patient) {
            final profile = profileAsync.valueOrNull;
            if (patient == null || profile == null) {
              return Center(
                child: Text(
                  'Profile data unavailable',
                  style: TextStyle(color: t.textSecondary),
                ),
              );
            }
            return _buildContent(context, profile, patient);
          },
          loading:
              () => Center(child: CircularProgressIndicator(color: t.accent)),
          error:
              (e, _) => Center(
                child: Text(
                  'Error loading ID: $e',
                  style: TextStyle(color: t.error),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic profile, dynamic patient) {
    final t = context.tokens;
    final qrData = patient.qrCodeId as String;
    final dob =
        patient.dateOfBirth != null
            ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!)
            : 'N/A';
    final blood = (patient.bloodType as String?) ?? '—';
    final weight = patient.weight != null ? '${patient.weight} kg' : '—';
    final height = patient.height != null ? '${patient.height} cm' : '—';

    final conditionsAsync = ref.watch(medicalConditionsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tutorial Indicator ──────────────────────────────────
            SquircleCard(
              radius: AppSpacing.squircleGrouped,
              color: t.card,
              borderSide: BorderSide(color: t.divider),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: [
                  Icon(Iconsax.info_circle, color: t.accent, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the card to flip it and reveal your emergency QR Code for medical personnel.',
                      style: TextStyle(
                        fontFamily: 'DM Sans',
                        fontSize: 12,
                        color: t.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Interactive Flip Card ────────────────────────────────
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth;
                  final cardHeight = cardWidth / 1.58;

                  return GestureDetector(
                    onTap: _toggleCard,
                    child: MouseRegion(
                      onHover:
                          (event) => _updateTilt(
                            event.localPosition,
                            cardWidth,
                            cardHeight,
                          ),
                      onExit: (_) => _resetTilt(),
                      child: Listener(
                        onPointerDown:
                            (event) => _updateTilt(
                              event.localPosition,
                              cardWidth,
                              cardHeight,
                            ),
                        onPointerMove:
                            (event) => _updateTilt(
                              event.localPosition,
                              cardWidth,
                              cardHeight,
                            ),
                        onPointerUp: (_) => _resetTilt(),
                        onPointerCancel: (_) => _resetTilt(),
                        child: AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final isBack = _flipAnimation.value >= 0.5;
                            final flipRotation =
                                _flipAnimation.value * 3.141592653589793;

                            return TweenAnimationBuilder<Offset>(
                              tween: Tween<Offset>(
                                begin: Offset.zero,
                                end: Offset(_targetTiltX, _targetTiltY),
                              ),
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              builder: (context, tilt, _) {
                                final transform =
                                    Matrix4.identity()
                                      ..setEntry(3, 2, 0.001) // perspective
                                      ..rotateY(flipRotation)
                                      ..rotateX(tilt.dx)
                                      ..rotateY(tilt.dy);

                                return Transform(
                                  transform: transform,
                                  alignment: Alignment.center,
                                  child:
                                      isBack
                                          ? Transform(
                                            alignment: Alignment.center,
                                            transform:
                                                Matrix4.identity()
                                                  ..rotateY(3.141592653589793),
                                            child: AspectRatio(
                                              aspectRatio: 1.58,
                                              child: _buildCardBack(
                                                context,
                                                qrData,
                                              ),
                                            ),
                                          )
                                          : AspectRatio(
                                            aspectRatio: 1.58,
                                            child: _buildCardFront(
                                              context,
                                              profile,
                                              patient,
                                              dob,
                                              blood,
                                              weight,
                                              height,
                                            ),
                                          ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.rotate_left, size: 14, color: t.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Tap card to flip',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Action Buttons ────────────────────────────────────────
            _buildActions(context, patient),
            const SizedBox(height: 32),

            // ── Medical Summary Header ───────────────────────────────
            Text(
              'Emergency Medical Profile',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'First responders will see these public details instantly upon scanning the QR code.',
              style: TextStyle(
                fontSize: 12,
                color: t.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // ── Conditions List ──────────────────────────────────────
            conditionsAsync.when(
              loading:
                  () => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: t.accent),
                    ),
                  ),
              error: (error, _) {
                if (error is KYCRequiredException) {
                  return _buildKycRequiredBox();
                }
                return SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  borderSide: BorderSide(color: t.divider),
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Failed to load emergency records summary',
                      style: TextStyle(color: t.textSecondary, fontSize: 12),
                    ),
                  ),
                );
              },
              data: (conditions) {
                final publicConditions =
                    conditions.where((c) => c.isPublic).toList();
                if (publicConditions.isEmpty) {
                  return _buildEmptyConditionsBox();
                }
                return SquircleCard(
                  radius: AppSpacing.squircleGrouped,
                  color: t.card,
                  borderSide: BorderSide(color: t.divider),
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: List.generate(publicConditions.length, (i) {
                      final cond = publicConditions[i];
                      return Column(
                        children: [
                          if (i > 0) Divider(height: 1, color: t.divider),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: t.tint,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getTypeIcon(cond.conditionType),
                                    color: t.accent,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cond.description,
                                        style: TextStyle(
                                          fontFamily: 'DM Sans',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: t.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        cond.conditionType.toUpperCase(),
                                        style: t.monoMeta.copyWith(
                                          fontSize: 9,
                                          color: t.textSecondary,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (cond.severity != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _severityColor(
                                        cond.severity,
                                      ).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cond.severity!.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'DM Sans',
                                        color: _severityColor(cond.severity),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                );
              },
            ),

            if (_screenshotProtectionEnabled) ...[
              const SizedBox(height: 24),
              _buildProtectionBanner(),
            ],

            const SizedBox(height: 32),
            // ── Footer note ──────────────────────────────────────────
            Center(
              child: Text(
                'This digital ID contains encrypted access keys.\nAudit trails log every scan event for your privacy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: t.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card Front ──────────────────────────────────────────────────────────
  Widget _buildCardFront(
    BuildContext context,
    dynamic profile,
    dynamic patient,
    String dob,
    String blood,
    String weight,
    String height,
  ) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.divider, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Card header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.heart5, color: t.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'CareSync',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                Text(
                  'MEDICAL PASSPORT',
                  style: t.monoMeta.copyWith(
                    color: t.textSecondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),

            // Middle section: avatar + name + verification
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.scaffold,
                    border: Border.all(color: t.divider, width: 1.0),
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
                          ? Center(
                            child: Text(
                              (profile.fullName as String).isNotEmpty
                                  ? (profile.fullName as String)
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : 'P',
                              style: TextStyle(
                                color: t.accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              profile.fullName as String,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Iconsax.verify5, color: t.accent, size: 15),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'MEMBER ID: ${profile.id.toString().substring(0, 8).toUpperCase()}-${profile.id.toString().substring(profile.id.toString().length - 4).toUpperCase()}',
                        style: t.monoMeta.copyWith(
                          color: t.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom row details (vitals)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardStat('BLOOD TYPE', blood),
                _buildCardStat('DATE OF BIRTH', dob),
                _buildCardStat('WEIGHT', weight),
                _buildCardStat('HEIGHT', height),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build card stats
  Widget _buildCardStat(String label, String value) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.monoMeta.copyWith(
            color: t.textSecondary,
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ── Card Back (houses scan surface) ──────────────────────────────────────
  Widget _buildCardBack(BuildContext context, String qrData) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.divider, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.heart5, color: t.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'CareSync',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                Text(
                  'EMERGENCY PASS',
                  style: t.monoMeta.copyWith(
                    color: t.textSecondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),

            // QR wrapper — fixed black-on-white for scannability in any theme.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.divider),
                  ),
                  width: 104,
                  height: 104,
                  child: PrettyQrView.data(
                    data: qrData,
                    errorCorrectLevel: QrErrorCorrectLevel.H,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),

            // Back footer secure tag
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.shield_tick, color: t.textSecondary, size: 12),
                const SizedBox(width: 6),
                Text(
                  'SECURE DISPATCH QR ACCESS',
                  style: t.monoMeta.copyWith(
                    color: t.textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions Buttons Widget ──────────────────────────────────────────────
  Widget _buildActions(BuildContext context, dynamic patient) {
    final t = context.tokens;
    return Row(
      children: [
        // Share Button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Share.share(
                'My CareSync Emergency Medical ID:\n'
                'ID: ${patient.qrCodeId}\n\n'
                'Ask a first responder to scan this in the CareSync app.',
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: t.divider),
              foregroundColor: t.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(Iconsax.share, size: 18, color: t.textSecondary),
            label: const Text(
              'Share ID',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Add to Wallet Button
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Add to Wallet coming soon'),
                  backgroundColor: t.accent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: t.accent,
              foregroundColor: t.accentOn,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Iconsax.wallet_1, size: 18),
            label: const Text(
              'Add to Wallet',
              style: TextStyle(
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Medical Summary helper widgets ───────────────────────────────────────
  // Deprecated _buildConditionRow. Conditions are now built inline as a grouped card.

  Widget _buildKycRequiredBox() {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Iconsax.shield_security, size: 36, color: t.accent),
          const SizedBox(height: 12),
          Text(
            'KYC Verification Required',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verify your KYC to link and review emergency health records.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: t.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConditionsBox() {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Iconsax.document_text, color: t.textSecondary, size: 28),
          const SizedBox(height: 10),
          Text(
            'No Public Emergency Vitals Linked',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Go to Medical Records and toggle conditions as "Visible on emergency pass".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: t.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Helper styling methods ───────────────────────────────────────────────
  Color _severityColor(String? severity) {
    final t = context.tokens;
    switch (severity) {
      case 'critical':
      case 'severe':
        return t.error;
      case 'moderate':
        return t.accent;
      default:
        return t.textSecondary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'allergy':
        return Iconsax.warning_2;
      case 'chronic':
        return Iconsax.activity;
      case 'medication':
        return Iconsax.document_text;
      default:
        return Iconsax.document_text;
    }
  }

  Widget _buildProtectionBanner() {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      color: t.tint,
      borderSide: BorderSide(color: t.accent.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Iconsax.shield_tick, color: t.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            'Screenshot protection active',
            style: TextStyle(
              color: t.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
