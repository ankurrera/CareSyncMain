import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.scaffold,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HERO SECTION ─────────────────────────────────
            Container(
              color: t.card,
              padding: EdgeInsets.fromLTRB(
                28,
                size.height * 0.06,
                28,
                size.height * 0.05,
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo_foreground.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Text(
                      'CARESYNC',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: t.textPrimary,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your unified healthcare companion',
                    style: TextStyle(
                      fontSize: 13,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 1, color: t.divider),

            // ── LABEL (mono section header) ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
              child: Text(
                'CHOOSE YOUR PORTAL',
                style: t.monoSectionHeader.copyWith(letterSpacing: 1.5),
              ),
            ),

            // ── PORTAL CARDS ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildOption(
                    context,
                    role: 'patient',
                    title: 'Patient',
                    subtitle: 'Medical records, appointments & emergency pass',
                    icon: Iconsax.user,
                    badgeLabel: 'PERSONAL',
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    context,
                    role: 'doctor',
                    title: 'Doctor',
                    subtitle: 'Consultations, prescriptions & patient history',
                    icon: Iconsax.health,
                    badgeLabel: 'CLINICAL',
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    context,
                    role: 'pharmacist',
                    title: 'Pharmacist',
                    subtitle: 'Dispense medicines & verify patient records',
                    icon: Iconsax.hospital,
                    badgeLabel: 'PHARMACY',
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── FOOTER ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.lock_1, size: 12, color: t.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    'Protected by end-to-end encryption',
                    style: TextStyle(
                      fontSize: 11,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeLabel,
  }) {
    final t = context.tokens;
    return SquircleCard(
      radius: AppSpacing.squircleGrouped,
      color: t.card,
      borderSide: BorderSide(color: t.divider),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      onTap: () => context.push(RouteNames.signIn, extra: role),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: t.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: t.textSecondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeLabel,
                        style: t.monoMeta.copyWith(
                          fontSize: 8,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: t.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: t.textSecondary, size: 22),
        ],
      ),
    );
  }
}
