import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../routing/route_names.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP HERO SECTION (white card feel) ───────────────
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(28, size.height * 0.06, 28, size.height * 0.05),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo_foreground.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'CARESYNC',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0D0D0D),
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your unified healthcare companion',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // ── DIVIDER ──────────────────────────────────────────
            Container(height: 1, color: const Color(0xFFE5E7EB)),

            // ── LABEL ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 14),
              child: Text(
                'CHOOSE YOUR PORTAL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF374151),
                  letterSpacing: 1.5,
                ),
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
                    icon: Icons.person_outline_rounded,
                    badgeLabel: 'PERSONAL',
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    context,
                    role: 'doctor',
                    title: 'Doctor',
                    subtitle: 'Consultations, prescriptions & patient history',
                    icon: Icons.medical_services_outlined,
                    badgeLabel: 'CLINICAL',
                  ),
                  const SizedBox(height: 10),
                  _buildOption(
                    context,
                    role: 'pharmacist',
                    title: 'Pharmacist',
                    subtitle: 'Dispense medicines & verify patient records',
                    icon: Icons.local_pharmacy_outlined,
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
                  const Icon(Icons.lock_outline_rounded,
                      size: 12, color: Color(0xFFD1D5DB)),
                  const SizedBox(width: 5),
                  Text(
                    'Protected by end-to-end encryption',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFFD1D5DB),
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
    return GestureDetector(
      onTap: () => context.push(RouteNames.signIn, extra: role),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: const Color(0xFF1F2937)),
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
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6B7280),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
