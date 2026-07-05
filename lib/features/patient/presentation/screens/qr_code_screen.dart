import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/biometric_guard.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/patient_provider.dart';

// ── Design tokens (mirrored from patient_dashboard_screen) ──────────────────
const _kBg       = Color(0xFFFAFAFA);
const _kInk      = Color(0xFF121212);
const _kOrange   = Color(0xFFFF5200);
const _kSlate    = Color(0xFF64748B);
const _kBorder   = Color(0xFFE2E8F0);
const _kSurface  = Color(0xFFFAFAFA);
const _kGreen    = Color(0xFF22C55E);
const _kGreenBg  = Color(0xFFF0FDF4);
const _kRed      = Color(0xFFEF4444);

class QrCodeScreen extends ConsumerStatefulWidget {
  const QrCodeScreen({super.key});

  @override
  ConsumerState<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends ConsumerState<QrCodeScreen> {
  bool _screenshotProtectionEnabled = false;

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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Minimal light header ─────────────────────────────────
          _buildHeroHeader(profile, patient),
          Divider(height: 1, color: _kBorder),

          // ── Scrollable body ──────────────────────────────────────
          Container(
            color: _kBg,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Vital stats section ──────────────────────────────────
                Text(
                  'Medical Information',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 14),
                _buildVitalsCard(dob, blood, weight, height),
                const SizedBox(height: 28),

                // ── QR section ───────────────────────────────────────────
                Text(
                  'Emergency QR Code',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'First responders scan this code to instantly access your medical profile.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _kSlate,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildQrCard(qrData),
                const SizedBox(height: 28),

                // ── Action buttons ───────────────────────────────────────
                _buildActions(context, patient),

                if (_screenshotProtectionEnabled) ...[
                  const SizedBox(height: 16),
                  _buildProtectionBanner(),
                ],

                const SizedBox(height: 16),
                // ── Footer note ──────────────────────────────────────────
                Center(
                  child: Text(
                    'This QR contains your unique medical ID.\nPresent it to any CareSync first responder.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _kSlate,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Minimal light header ──────────────────────────────────────────────────
  Widget _buildHeroHeader(dynamic profile, dynamic patient) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kOrange,
              border: Border.all(color: _kBorder, width: 2),
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          // Name + ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName as String,
                  style: GoogleFonts.plusJakartaSans(
                    color: _kInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID: ${(profile.id as String).substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.robotoMono(
                    color: _kSlate,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          // Emergency pass pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kOrange.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.scan, size: 12, color: _kOrange),
                const SizedBox(width: 5),
                Text(
                  'EMERGENCY',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kOrange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vitals card (white, border, subtle shadow — matches dashboard cards) ──
  Widget _buildVitalsCard(
      String dob, String blood, String weight, String height) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildVitalStat(
              icon: Iconsax.calendar_1,
              label: 'DATE OF BIRTH',
              value: dob,
              iconColor: _kSlate),
          _buildDivider(),
          _buildVitalStat(
              icon: Iconsax.heart,
              label: 'BLOOD TYPE',
              value: blood,
              valueColor: _kRed,
              iconColor: _kRed),
          _buildDivider(),
          _buildVitalStat(
              icon: Iconsax.weight,
              label: 'WEIGHT',
              value: weight,
              iconColor: _kSlate),
          _buildDivider(),
          _buildVitalStat(
              icon: Iconsax.ruler,
              label: 'HEIGHT',
              value: height,
              iconColor: _kSlate),
        ],
      ),
    );
  }

  Widget _buildVitalStat({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Color? iconColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? _kSlate),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 8,
              color: _kSlate,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _kInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: _kBorder);
  }

  // ── QR card (white, branded, clean) ───────────────────────────────────────
  Widget _buildQrCard(String qrData) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // QR verified header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBorder),
                ),
                child: const Icon(Iconsax.barcode, color: _kInk, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Emergency QR',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _kInk,
                      ),
                    ),
                    Text(
                      'Tap to enlarge • High error correction',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _kSlate,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGreenBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: _kGreen, size: 6),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: GoogleFonts.plusJakartaSans(
                        color: _kGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // QR Code itself
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder, width: 1.5),
            ),
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
          const SizedBox(height: 16),

          // "Verified by CareSync" footer row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.verify5, color: _kGreen, size: 14),
              const SizedBox(width: 6),
              Text(
                'Verified by CareSync',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: _kGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context, dynamic patient) {
    return Row(
      children: [
        // Share — outline style (matches dashboard "Remind Later")
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
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(Iconsax.share, size: 18, color: _kSlate),
            label: Text(
              'Share ID',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold, color: _kInk),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Add to Wallet — ink solid (matches dashboard "Enroll Now")
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Add to Wallet coming soon',
                      style: GoogleFonts.plusJakartaSans()),
                  backgroundColor: _kInk,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kInk,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            icon: Icon(Iconsax.wallet_1, size: 18),
            label: const Text('Add to Wallet'),
          ),
        ),
      ],
    );
  }

  // ── Screenshot protection banner ───────────────────────────────────────────
  Widget _buildProtectionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kGreenBg,
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