import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Branding
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Iconsax.health,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CareSync',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121212),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 54),
              // Headings
              Text(
                'Welcome to CareSync',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF121212),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your role to get started with the healthcare portal',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Role options
              _buildRoleItem(
                context,
                title: 'Patient Portal',
                description: 'Manage your medical records, check appointments, and view emergency pass.',
                icon: Iconsax.user,
                color: AppColors.patient,
                role: 'patient',
              ),
              const SizedBox(height: 16),
              _buildRoleItem(
                context,
                title: 'Doctor Portal',
                description: 'Consult patients, write digital prescriptions, and check history.',
                icon: Iconsax.teacher,
                color: AppColors.doctor,
                role: 'doctor',
              ),
              const SizedBox(height: 16),
              _buildRoleItem(
                context,
                title: 'Pharmacist Portal',
                description: 'Dispense prescribed medicines, verify patients, and log details.',
                icon: Icons.medication_rounded,
                color: AppColors.pharmacist,
                role: 'pharmacist',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleItem(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String role,
  }) {
    return InkWell(
      onTap: () => context.push(RouteNames.signIn, extra: role),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF121212),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow indicator
            const Icon(
              Iconsax.arrow_right_1,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
