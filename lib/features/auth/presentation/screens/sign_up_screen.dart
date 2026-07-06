import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  final String role;

  const SignUpScreen({super.key, required this.role});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Patient Specific Controllers & State
  final _weightController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  final _dobController = TextEditingController();

  // Doctor Specific Controllers
  final _hospitalController = TextEditingController();
  final _specializationController = TextEditingController();
  final _medRegController = TextEditingController();

  // Pharmacist Specific Controllers
  final _pharmacyNameController = TextEditingController();
  final _pharmacyAddressController = TextEditingController();
  final _pharmacistLicenseController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _weightController.dispose();
    _dobController.dispose();
    _hospitalController.dispose();
    _specializationController.dispose();
    _medRegController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyAddressController.dispose();
    _pharmacistLicenseController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Color get _roleColor {
    switch (widget.role) {
      case 'doctor':
        return AppColors.doctor;
      case 'pharmacist':
        return AppColors.pharmacist;
      default:
        return AppColors.patient;
    }
  }

  String get _roleTitle {
    switch (widget.role) {
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      default:
        return 'Patient';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D0D0D),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        role: widget.role,
        hospitalName: widget.role == 'doctor' ? _hospitalController.text.trim() : null,
        specialization: widget.role == 'doctor' ? _specializationController.text.trim() : null,
        medicalRegNumber: widget.role == 'doctor' ? _medRegController.text.trim() : null,
        pharmacyName: widget.role == 'pharmacist' ? _pharmacyNameController.text.trim() : null,
        pharmacyAddress: widget.role == 'pharmacist' ? _pharmacyAddressController.text.trim() : null,
        pharmacistLicenseNumber: widget.role == 'pharmacist' ? _pharmacistLicenseController.text.trim() : null,
        gender: widget.role == 'patient' ? _selectedGender : null,
        dateOfBirth: widget.role == 'patient' ? _selectedDateOfBirth : null,
        weight: widget.role == 'patient' && _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
      );

      if (mounted) {
        if (widget.role == 'patient') {
          context.go(RouteNames.kycVerification);
        } else {
          context.go(RouteNames.biometricEnrollment);
        }
      }
    } catch (e) {
      if (mounted) {
        final originalError = e.toString();
        String errorMessage = originalError;
        bool showSignInAction = false;

        if (originalError.contains('over_email_send_rate_limit')) {
          errorMessage = '⏱️ Too many sign-up attempts. Please wait a minute and try again.';
        } else if (originalError.contains('User already registered') || originalError.contains('already registered')) {
          errorMessage = '📧 This email is already registered. Try signing in instead.';
          showSignInAction = true;
        } else if (originalError.contains('Invalid email') || originalError.contains('invalid email')) {
          errorMessage = '📧 Please enter a valid email address.';
        } else if (originalError.contains('Password') && originalError.contains('weak')) {
          errorMessage = '🔒 Password is too weak. Use at least 8 characters with letters and numbers.';
        } else if (originalError.contains('Email not confirmed')) {
          errorMessage = '📬 Please check your email and verify your account before signing in.';
        } else if (originalError.contains('Network') || originalError.contains('network')) {
          errorMessage = '📡 Network error. Please check your connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: showSignInAction
                ? SnackBarAction(
              label: 'Sign In',
              textColor: Colors.white,
              onPressed: () => context.pop(),
            )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDoctor = widget.role == 'doctor';
    final isPatient = widget.role == 'patient';
    final isPharmacist = widget.role == 'pharmacist';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.015),

                  // ── 1. LOGO & BRANDING ──────────────────────────
                  Center(
                    child: Image.asset(
                      'assets/logo_foreground.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'CARESYNC',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF0D0D0D),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_roleTitle.toUpperCase()} PORTAL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your healthcare account',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.1,
                    ),
                  ),

                  SizedBox(height: size.height * 0.04),

                  // ── 2. INPUT FIELDS ─────────────────────────────
                  _buildLabel('Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fullNameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D0D0D),
                    ),
                    cursorColor: const Color(0xFF0D0D0D),
                    decoration: _inputDecoration(
                      hint: 'Enter your full name',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Full name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Email Address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D0D0D),
                    ),
                    cursorColor: const Color(0xFF0D0D0D),
                    decoration: _inputDecoration(
                      hint: 'Enter your email address',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Email is required';
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Phone Number'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D0D0D),
                    ),
                    cursorColor: const Color(0xFF0D0D0D),
                    decoration: _inputDecoration(
                      hint: 'Enter your phone number',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Phone number is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // PATIENT SPECIFIC FIELDS
                  if (isPatient) ...[
                    _buildLabel('Gender'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      decoration: _inputDecoration(
                        hint: 'Select your gender',
                        icon: Icons.people_outline_rounded,
                      ),
                      value: _selectedGender,
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _selectedGender = val),
                      validator: (val) => val == null ? 'Gender selection is required' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Date of Birth'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _dobController,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D0D0D),
                          ),
                          decoration: _inputDecoration(
                            hint: 'YYYY-MM-DD',
                            icon: Icons.calendar_today_outlined,
                          ),
                          validator: (value) => (value == null || value.isEmpty) ? 'Date of birth is required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Weight (kg)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'e.g. 70.5',
                        icon: Icons.monitor_weight_outlined,
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Enter a valid weight';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // DOCTOR SPECIFIC FIELDS
                  if (isDoctor) ...[
                    _buildLabel('Hospital / Clinic Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _hospitalController,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'Where do you practice?',
                        icon: Icons.local_hospital_outlined,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Hospital name is required' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Specialization'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _specializationController,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'e.g. Cardiologist, General Physician',
                        icon: Icons.school_outlined,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Specialization is required' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Medical Registration No. (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _medRegController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'Enter medical registration ID',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // PHARMACIST SPECIFIC FIELDS
                  if (isPharmacist) ...[
                    _buildLabel('Pharmacy Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pharmacyNameController,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'e.g. CareSync Pharmacy, Walgreens',
                        icon: Icons.local_pharmacy_outlined,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Pharmacy name is required' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Pharmacy Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pharmacyAddressController,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'Where is the pharmacy located?',
                        icon: Icons.location_on_outlined,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'Pharmacy address is required' : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Pharmacist License Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pharmacistLicenseController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D0D0D),
                      ),
                      cursorColor: const Color(0xFF0D0D0D),
                      decoration: _inputDecoration(
                        hint: 'Enter your license ID',
                        icon: Icons.badge_outlined,
                      ),
                      validator: (value) => (value == null || value.isEmpty) ? 'License number is required' : null,
                    ),
                    const SizedBox(height: 20),
                  ],

                  _buildLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D0D0D),
                    ),
                    cursorColor: const Color(0xFF0D0D0D),
                    decoration: _inputDecoration(
                      hint: 'Create a password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password is required';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0D0D0D),
                    ),
                    cursorColor: const Color(0xFF0D0D0D),
                    decoration: _inputDecoration(
                      hint: 'Confirm your password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Password confirmation is required';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── 3. BUTTON ───────────────────────────────────
                  GestureDetector(
                    onTap: _isLoading ? null : _signUp,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        'CREATE ACCOUNT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── 4. SIGN IN ROUTE LINK ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF6B7280),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF0D0D0D),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // ── 5. SECURITY NOTE ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 6),
                      Text(
                        'Secured with end-to-end encryption',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.04),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF374151),
        letterSpacing: 1,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF9CA3AF),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0D0D0D), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
