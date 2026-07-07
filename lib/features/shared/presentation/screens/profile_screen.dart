import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/rendering.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/presentation/screens/family_members_screen.dart';
import '../../../family/providers/family_provider.dart';
import '../../models/user_profile.dart';

// Provider for doctor signature status
final doctorSignatureProvider = FutureProvider<String?>((ref) async {
  return await SecureStorageService.instance.getDoctorSignature();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(activeContextProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final activeId = ref.watch(activeProfileIdProvider);
    final isUsingFamilyAccount = authUser != null && activeId != authUser.id;

    final kycAsync = ref.watch(kycStatusProvider);
    final familyMembersAsync = ref.watch(familyMembersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Parchment surface background
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: CircularProgressIndicator(color: Color(0xFF121212)),
              ),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Text('Error loading profile: $err', style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444))),
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Text("Profile not found", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B))),
                  ),
                );
              }

              final isVerified = kycAsync.valueOrNull?.status == KYCStatus.verified;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Family Account Banner
                  if (isUsingFamilyAccount)
                    _buildFamilyBanner(context, ref, profile),

                  // Custom App Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF121212), size: 20),
                        onPressed: () => context.pop(),
                      ),
                      Text(
                        'Account Profile',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF121212),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatar Center Section
                  Center(
                    child: Column(
                      children: [
                        _buildAvatar(profile, isVerified),
                        const SizedBox(height: 16),
                        Text(
                          profile.fullName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF121212),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildVerificationBadge(context, isVerified, isUsingFamilyAccount),
                        const SizedBox(height: 16),

                        // Inline Mini-Stats Row (Patient only)
                        if (profile.isPatient && !isUsingFamilyAccount) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMiniStatItem(
                                label: 'Connected Devices',
                                value: '2',
                                icon: Iconsax.mobile,
                                onTap: () => context.push(RouteNames.deviceManagement),
                              ),
                              Container(
                                width: 1,
                                height: 16,
                                color: const Color(0xFFE2E8F0),
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              _buildMiniStatItem(
                                label: 'Dependents',
                                value: familyMembersAsync.valueOrNull?.length.toString() ?? '0',
                                icon: Iconsax.people,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                        ],
                      ],
                    ),
                  ),

                  // Professional Info for Doctors
                  if (profile.isDoctor) ...[
                    const SizedBox(height: 12),
                    _buildDoctorDetailsCard(context, ref, profile),
                    const SizedBox(height: 28),
                  ],

                  // Professional Info for Pharmacists
                  if (profile.isPharmacist) ...[
                    const SizedBox(height: 12),
                    _buildPharmacistDetailsCard(context, ref, profile),
                    const SizedBox(height: 28),
                  ],

                  // Settings / Actions List
                  if (!isUsingFamilyAccount) ...[
                    // Switch Account Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          backgroundColor: Colors.white,
                          elevation: 0,
                        ),
                        icon: Icon(Iconsax.arrow_swap, color: const Color(0xFF121212), size: 16),
                        label: Text(
                          'Switch Profile View',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF121212),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          _showAccountSwitcher(context, ref, familyMembersAsync);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Settings Heading
                    Text(
                      'Account Settings',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF121212),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Settings list items container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          if (profile.isPatient) ...[
                            _buildSettingsTile(
                              icon: Iconsax.people,
                              title: 'Family & Dependents',
                              onTap: () => Navigator.push(
                                context,
                                  MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
                              ),
                            ),
                            _buildSettingsTile(
                              icon: Iconsax.security_safe,
                              title: 'Privacy & Security Settings',
                              onTap: () => context.push(RouteNames.patientPrivacy),
                            ),
                          ],

                          _buildSettingsTile(
                            icon: Iconsax.lock,
                            title: 'Change Password',
                            onTap: () {},
                          ),
                          _buildSettingsTile(
                            icon: Iconsax.logout,
                            title: 'Sign Out',
                            isDestructive: true,
                            onTap: () {
                              ref.read(authNotifierProvider.notifier).signOut();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildVerificationBadge(BuildContext context, bool isVerified, bool isUsingFamilyAccount) {
    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5), // soft emerald bg
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xA110B981), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Color(0xFF059669), size: 12),
            const SizedBox(width: 4),
            Text(
              'VERIFIED ID',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF059669),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: isUsingFamilyAccount ? null : () => context.push(RouteNames.kycVerification),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7), // soft amber bg
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xA1F59E0B), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, color: Color(0xFFD97706), size: 12),
            const SizedBox(width: 4),
            Text(
              'UNVERIFIED (COMPLETE KYC)',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD97706),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatItem({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFFF5200)),
              const SizedBox(width: 6),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF121212),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorDetailsCard(BuildContext context, WidgetRef ref, UserProfile profile) {
    final signatureAsync = ref.watch(doctorSignatureProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Iconsax.briefcase,
            title: 'Specialization: ${profile.specialization ?? 'Not set'}',
          ),
          _buildSettingsTile(
            icon: Iconsax.teacher,
            title: 'Workplace: ${profile.hospitalName ?? 'Not set'}',
            onTap: () => _showEditDoctorProfile(context, ref, profile),
          ),
          if (profile.medicalRegNumber != null)
            _buildSettingsTile(
              icon: Iconsax.card,
              title: 'Reg. Number: ${profile.medicalRegNumber!}',
            ),
          _buildSettingsTile(
            icon: Iconsax.edit_2,
            title: signatureAsync.valueOrNull != null ? 'Digital Signature: Enrolled' : 'Digital Signature: Not Set',
            onTap: () => _showSignaturePadDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildPharmacistDetailsCard(BuildContext context, WidgetRef ref, UserProfile profile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Iconsax.briefcase,
            title: 'Pharmacy Name: ${profile.pharmacyName ?? 'Not set'}',
            onTap: () => _showEditPharmacistProfile(context, ref, profile),
          ),
          _buildSettingsTile(
            icon: Iconsax.location,
            title: 'Pharmacy Address: ${profile.pharmacyAddress ?? 'Not set'}',
            onTap: () => _showEditPharmacistProfile(context, ref, profile),
          ),
          if (profile.licenseNumber != null)
            _buildSettingsTile(
              icon: Iconsax.card,
              title: 'License Number: ${profile.licenseNumber!}',
            ),
        ],
      ),
    );
  }

  Widget _buildFamilyBanner(BuildContext context, WidgetRef ref, UserProfile profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Iconsax.arrow_swap, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Viewing Family Profile', style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 11)),
                Text(
                  profile.fullName,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => ref.read(familyControllerProvider.notifier).switchAccount(null),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.close, size: 14),
            label: Text('Exit', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserProfile profile, bool isVerified) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        image: profile.avatarUrl != null
            ? DecorationImage(image: NetworkImage(profile.avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: profile.avatarUrl == null
          ? const Icon(Iconsax.user, size: 36, color: Color(0xFF94A3B8))
          : null,
    );
  }

  void _showAccountSwitcher(BuildContext context, WidgetRef ref, AsyncValue<List<dynamic>> membersAsync) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.arrow_swap, color: const Color(0xFFFF5200)),
                const SizedBox(width: 12),
                Text(
                  'Switch Active Profile',
                  style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF121212)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "No linked family accounts yet.",
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF64748B)),
                    ),
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ActionChip(
                      backgroundColor: const Color(0xFFFAFAFA),
                      avatar: const Icon(Iconsax.user, size: 14),
                      label: Text('Primary Account', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        ref.read(familyControllerProvider.notifier).switchAccount(null);
                        Navigator.pop(context);
                      },
                    ),
                    ...members.map((member) => ActionChip(
                      backgroundColor: const Color(0xFFFAFAFA),
                      avatar: CircleAvatar(
                        backgroundColor: const Color(0xFFFF5200),
                        child: Text(
                          member.profile.fullName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      label: Text(member.profile.fullName, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                      onPressed: () {
                        ref.read(familyControllerProvider.notifier).switchAccount(member.profile.id);
                        Navigator.pop(context);
                      },
                    )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF121212))),
              error: (_,__) => Text("Error loading linked profiles", style: GoogleFonts.plusJakartaSans(color: const Color(0xFFEF4444))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    bool isToggle = false,
    bool toggleValue = false,
    ValueChanged<bool>? onToggle,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDestructive ? const Color(0xFFFEE2E2) : const Color(0xFFFAFAFA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF121212),
            ),
          ),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDestructive ? const Color(0xFFEF4444) : const Color(0xFF121212),
            ),
          ),
          trailing: isToggle
              ? Switch.adaptive(
                  value: toggleValue,
                  activeTrackColor: const Color(0xFFFF5200),
                  onChanged: onToggle,
                )
              : (onTap != null
                  ? const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18)
                  : null),
        ),
        if (!isDestructive)
          const Divider(height: 1, indent: 60, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  void _showEditDoctorProfile(BuildContext context, WidgetRef ref, UserProfile profile) {
    final hospitalController = TextEditingController(text: profile.hospitalName);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Edit Workplace',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: hospitalController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Hospital / Clinic Name',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: profile.specialization,
                    readOnly: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Specialization (Locked)',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      prefixIcon: const Icon(Iconsax.lock, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (hospitalController.text.trim().isEmpty) return;

                    setState(() => isLoading = true);
                    try {
                      await SupabaseService.instance.upsertProfile({
                        'hospital_clinic_name': hospitalController.text.trim(),
                      });

                      ref.invalidate(currentProfileProvider);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Workplace profile updated successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
      ),
    );
  }

  void _showEditPharmacistProfile(BuildContext context, WidgetRef ref, UserProfile profile) {
    final nameController = TextEditingController(text: profile.pharmacyName);
    final addressController = TextEditingController(text: profile.pharmacyAddress);
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Edit Pharmacy Profile',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Pharmacy Name',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Pharmacy Address',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: profile.licenseNumber,
                    readOnly: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'License Number (Locked)',
                      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13),
                      prefixIcon: const Icon(Iconsax.lock, size: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (nameController.text.trim().isEmpty || addressController.text.trim().isEmpty) return;

                    setState(() => isLoading = true);
                    try {
                      await SupabaseService.instance.upsertProfile({
                        'pharmacy_name': nameController.text.trim(),
                        'pharmacy_address': addressController.text.trim(),
                        'role': 'pharmacist',
                      });

                      ref.invalidate(currentProfileProvider);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pharmacy profile updated successfully')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
      ),
    );
  }

  void _showSignaturePadDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _SignatureDialog(ref: ref);
      },
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  final WidgetRef ref;
  const _SignatureDialog({required this.ref});

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final List<Offset?> _points = [];
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _save() async {
    if (_points.where((p) => p != null).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw your signature first'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final base64String = base64Encode(bytes);
        final hash = sha256.convert(bytes).toString();

        // 1. Save locally
        await SecureStorageService.instance.setDoctorSignature(base64String);
        await SecureStorageService.instance.setDoctorSignatureHash(hash);
        
        // 2. Save to Supabase doctors table
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
            const SnackBar(
              content: Text('Digital signature enrolled successfully'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error saving signature: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      title: Text(
        'Draw Signature',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: const Color(0xFF111827),
        ),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Draw your official prescription signature inside the box below.',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            height: 180,
            width: 280,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    painter: _SignaturePainter(_points),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEF4444),
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await SecureStorageService.instance.setDoctorSignature('');
                  await SecureStorageService.instance.setDoctorSignatureHash('');
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
                      debugPrint('Error removing signature from database: $e');
                    }
                  }
                  widget.ref.invalidate(doctorSignatureProvider);
                  widget.ref.invalidate(currentProfileProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  'Reset/Remove',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF374151),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Save Stamp',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF1E3A8A)
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