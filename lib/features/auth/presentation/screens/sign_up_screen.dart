import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/circular_icon_button.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
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
      await ref
          .read(authNotifierProvider.notifier)
          .signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            role: widget.role,
            hospitalName:
                widget.role == 'doctor'
                    ? _hospitalController.text.trim()
                    : null,
            specialization:
                widget.role == 'doctor'
                    ? _specializationController.text.trim()
                    : null,
            medicalRegNumber:
                widget.role == 'doctor' ? _medRegController.text.trim() : null,
            pharmacyName:
                widget.role == 'pharmacist'
                    ? _pharmacyNameController.text.trim()
                    : null,
            pharmacyAddress:
                widget.role == 'pharmacist'
                    ? _pharmacyAddressController.text.trim()
                    : null,
            pharmacistLicenseNumber:
                widget.role == 'pharmacist'
                    ? _pharmacistLicenseController.text.trim()
                    : null,
            gender: widget.role == 'patient' ? _selectedGender : null,
            dateOfBirth: widget.role == 'patient' ? _selectedDateOfBirth : null,
            weight:
                widget.role == 'patient' && _weightController.text.isNotEmpty
                    ? double.tryParse(_weightController.text)
                    : null,
          );

      if (mounted) {
        if (widget.role == 'patient') {
          context.go(RouteNames.kycVerification);
        } else if (widget.role == 'doctor') {
          context.go(RouteNames.doctorDashboard);
        } else if (widget.role == 'pharmacist') {
          context.go(RouteNames.pharmacistDashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        final originalError = e.toString();
        String errorMessage = originalError;
        bool showSignInAction = false;

        if (originalError.contains('over_email_send_rate_limit')) {
          errorMessage =
              '⏱️ Too many sign-up attempts. Please wait a minute and try again.';
        } else if (originalError.contains('User already registered') ||
            originalError.contains('already registered')) {
          errorMessage =
              '📧 This email is already registered. Try signing in instead.';
          showSignInAction = true;
        } else if (originalError.contains('Invalid email') ||
            originalError.contains('invalid email')) {
          errorMessage = '📧 Please enter a valid email address.';
        } else if (originalError.contains('Password') &&
            originalError.contains('weak')) {
          errorMessage =
              '🔒 Password is too weak. Use at least 8 characters with letters and numbers.';
        } else if (originalError.contains('Email not confirmed')) {
          errorMessage =
              '📬 Please check your email and verify your account before signing in.';
        } else if (originalError.contains('Network') ||
            originalError.contains('network')) {
          errorMessage =
              '📡 Network error. Please check your connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: context.tokens.error,
            duration: const Duration(seconds: 5),
            action:
                showSignInAction
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
    final t = context.tokens;
    final isDoctor = widget.role == 'doctor';
    final isPatient = widget.role == 'patient';
    final isPharmacist = widget.role == 'pharmacist';

    return Scaffold(
      backgroundColor: t.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
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
                      child: CircularIconButton(
                        icon: Iconsax.arrow_left_2,
                        onTap: () => context.pop(),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.015),

                  // ── 1. LOGO & BRANDING ──────────────────────────
                  Center(
                    child: Image.asset(
                      'assets/logo_foreground.png',
                      height: 110,
                      width: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Text(
                    'CARESYNC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: t.tint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_roleTitle.toUpperCase()} PORTAL',
                        style: t.monoMeta.copyWith(
                          fontSize: 10,
                          color: t.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Create your healthcare account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: t.textSecondary),
                  ),

                  SizedBox(height: size.height * 0.035),

                  // ── 2. INPUT FIELDS ─────────────────────────────
                  _buildLabel('Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fullNameController,
                    textCapitalization: TextCapitalization.words,
                    style: _fieldStyle,
                    cursorColor: t.accent,
                    decoration: _inputDecoration(
                      hint: 'Enter your full name',
                      icon: Iconsax.user,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Full name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Email Address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: _fieldStyle,
                    cursorColor: t.accent,
                    decoration: _inputDecoration(
                      hint: 'Enter your email address',
                      icon: Iconsax.sms,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
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
                    style: _fieldStyle,
                    cursorColor: t.accent,
                    decoration: _inputDecoration(
                      hint: 'Enter your phone number',
                      icon: Iconsax.call,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Phone number is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // PATIENT SPECIFIC FIELDS
                  if (isPatient) ...[
                    _buildLabel('Gender'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      style: _fieldStyle,
                      decoration: _inputDecoration(
                        hint: 'Select your gender',
                        icon: Iconsax.people,
                      ),
                      initialValue: _selectedGender,
                      dropdownColor: t.card,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) => setState(() => _selectedGender = val),
                      validator:
                          (val) =>
                              val == null
                                  ? 'Gender selection is required'
                                  : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Date of Birth'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _dobController,
                          style: _fieldStyle,
                          decoration: _inputDecoration(
                            hint: 'YYYY-MM-DD',
                            icon: Iconsax.calendar_1,
                          ),
                          validator:
                              (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Date of birth is required'
                                      : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Weight (kg)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'e.g. 70.5',
                        icon: Iconsax.weight,
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
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'Where do you practice?',
                        icon: Iconsax.hospital,
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Hospital name is required'
                                  : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Specialization'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _specializationController,
                      textCapitalization: TextCapitalization.words,
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'e.g. Cardiologist, General Physician',
                        icon: Iconsax.teacher,
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Specialization is required'
                                  : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Medical Registration No. (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _medRegController,
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'Enter medical registration ID',
                        icon: Iconsax.card,
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
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'e.g. CareSync Pharmacy, Walgreens',
                        icon: Iconsax.hospital,
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Pharmacy name is required'
                                  : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Pharmacy Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pharmacyAddressController,
                      textCapitalization: TextCapitalization.words,
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'Where is the pharmacy located?',
                        icon: Iconsax.location,
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'Pharmacy address is required'
                                  : null,
                    ),
                    const SizedBox(height: 20),

                    _buildLabel('Pharmacist License Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pharmacistLicenseController,
                      style: _fieldStyle,
                      cursorColor: t.accent,
                      decoration: _inputDecoration(
                        hint: 'Enter your license ID',
                        icon: Iconsax.card,
                      ),
                      validator:
                          (value) =>
                              (value == null || value.isEmpty)
                                  ? 'License number is required'
                                  : null,
                    ),
                    const SizedBox(height: 20),
                  ],

                  _buildLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: _fieldStyle,
                    cursorColor: t.accent,
                    decoration: _inputDecoration(
                      hint: 'Create a password',
                      icon: Iconsax.lock_1,
                      suffix: IconButton(
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                        icon: Icon(
                          _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                          color: t.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Confirm Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: _fieldStyle,
                    cursorColor: t.accent,
                    decoration: _inputDecoration(
                      hint: 'Confirm your password',
                      icon: Iconsax.lock_1,
                      suffix: IconButton(
                        onPressed:
                            () => setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Iconsax.eye_slash
                              : Iconsax.eye,
                          color: t.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password confirmation is required';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── 3. BUTTON ───────────────────────────────────
                  CSPrimaryButton(
                    label: 'Create Account',
                    loading: _isLoading,
                    onPressed: _signUp,
                  ),

                  const SizedBox(height: 28),

                  // ── 4. SIGN IN ROUTE LINK ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: t.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // ── 5. SECURITY NOTE ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.shield_tick,
                        size: 13,
                        color: t.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Secured with end-to-end encryption',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.textSecondary,
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

  TextStyle get _fieldStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: context.tokens.textPrimary,
  );

  Widget _buildLabel(String text) {
    final t = context.tokens;
    return Text(
      text.toUpperCase(),
      style: t.monoMeta.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: t.textSecondary,
        letterSpacing: 1,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final t = context.tokens;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: t.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: t.textSecondary, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: t.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: t.divider, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: t.divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: t.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: t.error, width: 1),
      ),
    );
  }
}
