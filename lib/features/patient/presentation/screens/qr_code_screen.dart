import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/biometric_guard.dart';
import '../../../../services/kyc_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
import '../../models/patient_data.dart';

// ── Design tokens (mirrored from patient_dashboard_screen) ──────────────────
const _kBg       = Color(0xFFFAFAFA);
const _kInk      = Color(0xFF121212);
const _kOrange   = Color(0xFFFF5200);
const _kSlate    = Color(0xFF64748B);
const _kBorder   = Color(0xFFE2E8F0);
const _kGreen    = Color(0xFF22C55E);
const _kRed      = Color(0xFFEF4444);

class QrCodeScreen extends ConsumerStatefulWidget {
  const QrCodeScreen({super.key});

  @override
  ConsumerState<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends ConsumerState<QrCodeScreen> with SingleTickerProviderStateMixin {
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

    // normalize coordinates to range [-1.0, 1.0]
    final normX = (localPosition.dx / width) * 2 - 1;
    final normY = (localPosition.dy / height) * 2 - 1;

    // Clamp values
    final clampedX = normX.clamp(-1.0, 1.0);
    final clampedY = normY.clamp(-1.0, 1.0);

    // 15 degrees in radians is roughly 0.2618
    const maxTilt = 0.2618;

    setState(() {
      // Rotating around X axis tilts top/bottom (controlled by Y position)
      // Rotating around Y axis tilts left/right (controlled by X position)
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
    final profileAsync = ref.watch(currentProfileProvider);
    final patientAsync = ref.watch(patientDataProvider);

    return BiometricGuard(
      reason: 'Authenticate to view your Medical ID',
      strictMode: false,
      onAuthenticated: _onAuthenticated,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Digital Medical ID',
            style: GoogleFonts.plusJakartaSans(
              color: _kInk,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _kInk),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: _kBorder, height: 1.0),
          ),
        ),
        body: patientAsync.when(
          data: (patient) {
            final profile = profileAsync.valueOrNull;
            if (patient == null || profile == null) {
              return Center(
                child: Text(
                  'Profile data unavailable',
                  style: GoogleFonts.plusJakartaSans(color: _kSlate),
                ),
              );
            }
            return _buildContent(context, profile, patient);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: _kOrange),
          ),
          error: (e, _) => Center(
            child: Text('Error loading ID: $e',
                style: GoogleFonts.plusJakartaSans(color: _kRed)),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, dynamic profile, dynamic patient) {
    final qrData  = patient.qrCodeId as String;
    final dob     = patient.dateOfBirth != null
        ? DateFormat('dd MMM yyyy').format(patient.dateOfBirth!)
        : 'N/A';
    final blood   = (patient.bloodType as String?) ?? '—';
    final weight  = patient.weight  != null ? '${patient.weight} kg'  : '—';
    final height  = patient.height  != null ? '${patient.height} cm'  : '—';

    final conditionsAsync = ref.watch(medicalConditionsProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        color: _kBg,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tutorial Indicator ──────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle, color: _kOrange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the card to flip it and reveal your emergency QR Code for medical personnel.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _kSlate,
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
                      onHover: (event) => _updateTilt(event.localPosition, cardWidth, cardHeight),
                      onExit: (_) => _resetTilt(),
                      child: Listener(
                        onPointerDown: (event) => _updateTilt(event.localPosition, cardWidth, cardHeight),
                        onPointerMove: (event) => _updateTilt(event.localPosition, cardWidth, cardHeight),
                        onPointerUp: (_) => _resetTilt(),
                        onPointerCancel: (_) => _resetTilt(),
                        child: AnimatedBuilder(
                          animation: _flipAnimation,
                          builder: (context, child) {
                            final isBack = _flipAnimation.value >= 0.5;
                            final flipRotation = _flipAnimation.value * 3.141592653589793;

                            return TweenAnimationBuilder<Offset>(
                              tween: Tween<Offset>(
                                begin: Offset.zero,
                                end: Offset(_targetTiltX, _targetTiltY),
                              ),
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutCubic,
                              builder: (context, tilt, _) {
                                final transform = Matrix4.identity()
                                  ..setEntry(3, 2, 0.001) // perspective
                                  ..rotateY(flipRotation)
                                  ..rotateX(tilt.dx)
                                  ..rotateY(tilt.dy);

                                return Transform(
                                  transform: transform,
                                  alignment: Alignment.center,
                                  child: isBack
                                      ? Transform(
                                          alignment: Alignment.center,
                                          transform: Matrix4.identity()..rotateY(3.141592653589793),
                                          child: AspectRatio(
                                            aspectRatio: 1.58,
                                            child: _buildCardBack(context, qrData),
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
                  const Icon(Iconsax.rotate_left, size: 14, color: _kSlate),
                  const SizedBox(width: 6),
                  Text(
                    'Tap card to flip',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _kSlate,
                      fontWeight: FontWeight.bold,
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'First responders will see these public details instantly upon scanning the QR code.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _kSlate,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // ── Conditions List ──────────────────────────────────────
            conditionsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: _kOrange),
                ),
              ),
              error: (error, _) {
                if (error is KYCRequiredException) {
                  return _buildKycRequiredBox();
                }
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Center(
                    child: Text(
                      'Failed to load emergency records summary',
                      style: GoogleFonts.plusJakartaSans(color: _kSlate, fontSize: 12),
                    ),
                  ),
                );
              },
              data: (conditions) {
                final publicConditions = conditions.where((c) => c.isPublic).toList();
                if (publicConditions.isEmpty) {
                  return _buildEmptyConditionsBox();
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: publicConditions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cond = publicConditions[index];
                    return _buildConditionRow(cond);
                  },
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _kSlate,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card Front (Minimalist, flat white design with clean typography) ──────
  Widget _buildCardFront(
    BuildContext context,
    dynamic profile,
    dynamic patient,
    String dob,
    String blood,
    String weight,
    String height,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _kBorder.withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: _kBorder,
          width: 1.0,
        ),
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
                    const Icon(
                      Iconsax.heart5,
                      color: _kOrange,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CareSync',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kInk,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                Text(
                  'MEDICAL PASSPORT',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kSlate,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),

            // Middle section: flat avatar + inline check verification
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kBg,
                    border: Border.all(
                      color: _kBorder,
                      width: 1.0,
                    ),
                    image: profile.avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(profile.avatarUrl!),
                            fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: profile.avatarUrl == null
                          ? Center(
                              child: Text(
                                (profile.fullName as String).isNotEmpty
                                    ? (profile.fullName as String)
                                        .substring(0, 1)
                                        .toUpperCase()
                                    : 'P',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _kSlate,
                                  fontWeight: FontWeight.bold,
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
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _kInk,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Iconsax.verify5,
                                color: _kGreen,
                                size: 15,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'MEMBER ID: ${profile.id.toString().substring(0, 8).toUpperCase()}-${profile.id.toString().substring(profile.id.toString().length - 4).toUpperCase()}',
                            style: GoogleFonts.robotoMono(
                              color: _kSlate,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: _kSlate,
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: _kInk,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ── Card Back (Houses scan surface, flat white layout) ───────────────────
  Widget _buildCardBack(BuildContext context, String qrData) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _kBorder.withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: _kBorder,
          width: 1.0,
        ),
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
                    const Icon(Iconsax.heart5, color: _kOrange, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'CareSync',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kInk,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                Text(
                  'EMERGENCY PASS',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kSlate,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),

            // Branded, high-contrast QR wrapper
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  width: 104,
                  height: 104,
                  child: PrettyQrView.data(
                    data: qrData,
                    errorCorrectLevel: QrErrorCorrectLevel.H,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: _kInk,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Back footer secure tag
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.shield_tick, color: _kSlate, size: 12),
                const SizedBox(width: 6),
                Text(
                  'SECURE DISPATCH QR ACCESS',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kSlate,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
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
              side: const BorderSide(color: _kBorder),
              foregroundColor: _kInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Iconsax.share, size: 18, color: _kSlate),
            label: Text(
              'Share ID',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: _kInk,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Add to Wallet Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Add to Wallet coming soon',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                  backgroundColor: _kInk,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kInk,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Iconsax.wallet_1, size: 18),
            label: const Text('Add to Wallet'),
          ),
        ),
      ],
    );
  }

  // ── Medical Summary helper widgets ───────────────────────────────────────
  Widget _buildConditionRow(MedicalCondition cond) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getTypeColor(cond.conditionType).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getTypeIcon(cond.conditionType),
              color: _getTypeColor(cond.conditionType),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cond.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cond.conditionType.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: _kSlate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          if (cond.severity != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getSeverityColor(cond.severity!).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cond.severity!.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8,
                  color: _getSeverityColor(cond.severity!),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKycRequiredBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Iconsax.shield_security, size: 36, color: _kOrange),
          const SizedBox(height: 12),
          Text(
            'KYC Verification Required',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Verify your KYC to link and review emergency health records.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _kSlate,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyConditionsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Iconsax.document_text, color: _kSlate.withValues(alpha: 0.6), size: 28),
          const SizedBox(height: 10),
          Text(
            'No Public Emergency Vitals Linked',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: _kInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Go to Medical Records and toggle conditions as "Visible on emergency pass".',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: _kSlate,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper styling methods ───────────────────────────────────────────────
  Color _getTypeColor(String type) {
    switch (type) {
      case 'allergy':
        return const Color(0xFFEF4444);
      case 'chronic':
        return Colors.orange;
      case 'medication':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF64748B);
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

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
      case 'severe':
        return const Color(0xFFEF4444);
      case 'moderate':
        return Colors.orange;
      default:
        return const Color(0xFF10B981);
    }
  }

  Widget _buildProtectionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, // transparent fallback
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.shield_tick, color: _kGreen, size: 16),
          const SizedBox(width: 8),
          Text(
            'Screenshot protection active',
            style: GoogleFonts.plusJakartaSans(
              color: _kGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}