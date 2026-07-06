import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/two_factor_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';
import 'two_factor_verification_screen.dart';

class SignInScreen extends ConsumerStatefulWidget {
  final String role;

  const SignInScreen({super.key, required this.role});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isBiometricLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  IconData get _roleIcon {
    switch (widget.role) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'pharmacist':
        return Icons.local_pharmacy_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref.read(authNotifierProvider.notifier).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        // Refresh profile to get actual role from database
        ref.invalidate(currentProfileProvider);
        final profile = await ref.read(currentProfileProvider.future);
        
        if (profile == null) {
          throw Exception('Could not load profile');
        }

        // Validate role matches
        if (profile.role != widget.role) {
          // Sign out first
          await ref.read(authNotifierProvider.notifier).signOut();
          
          if (mounted) {
            // Show a dialog with the correct role info
            await _showRoleMismatchDialog(profile.role);
          }
          return;
        }

        // Handle different requirements based on sign-in result
        if (result.requiresTwoFactor && mounted) {
          // New device - require 2FA
          await _show2FADialog(result);
        } else if (result.requiresKyc && mounted) {
          // KYC not verified - redirect to KYC
          context.go(RouteNames.kycVerification);
        } else if (result.requiresBiometric && mounted) {
          // Biometric enrollment required - MANDATORY per spec
          // Use addPostFrameCallback to ensure navigation completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go(RouteNames.biometricEnrollment, extra: true);
            }
          });
        } else if (mounted) {
          // All requirements met - navigate to dashboard
          _navigateToDashboard(profile.role);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithBiometric() async {
    setState(() => _isBiometricLoading = true);

    try {
      // Attempt biometric authentication
      final success = await ref.read(authNotifierProvider.notifier).signInWithBiometric();

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Biometric authentication failed or session expired. Please sign in with your credentials.'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        // Refresh profile to get user data
        ref.invalidate(currentProfileProvider);
        final profile = await ref.read(currentProfileProvider.future);

        if (profile == null) {
          throw Exception('Could not load profile');
        }

        // Validate role matches
        if (profile.role != widget.role) {
          // Sign out first
          await ref.read(authNotifierProvider.notifier).signOut();

          if (mounted) {
            // Show a dialog with the correct role info
            await _showRoleMismatchDialog(profile.role);
          }
          return;
        }

        // Navigate to dashboard
        _navigateToDashboard(profile.role);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Biometric authentication failed. Please try again or sign in with your credentials.';
        
        // Handle specific error cases
        final errorStr = e.toString();
        if (errorStr.contains('session expired') || errorStr.contains('timed out')) {
          errorMessage = 'Session expired. Please sign in with your credentials.';
        } else if (errorStr.contains('canceled')) {
          errorMessage = 'Authentication canceled. Please try again or sign in with your credentials.';
        } else if (errorStr.contains('not enrolled')) {
          errorMessage = 'No biometrics enrolled. Please set up biometric authentication in your device settings.';
        } else if (errorStr.contains('not available')) {
          errorMessage = 'Biometric authentication is not available on this device.';
        } else if (errorStr.contains('locked')) {
          errorMessage = 'Too many failed attempts. Please try again later or sign in with your credentials.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  Future<void> _show2FADialog(SignInResult result) async {
    // Show dialog to choose 2FA method
    final method = await showDialog<TwoFactorCodeType>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Two-Factor Authentication'),
        content: const Text(
          'This is a new device. Please verify your identity using a verification code.',
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, TwoFactorCodeType.email),
            icon: const Icon(Icons.email),
            label: const Text('Email Code'),
          ),
          // SMS option can be added here if phone number is available
        ],
      ),
    );

    if (method != null && mounted) {
      // Navigate to 2FA verification screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TwoFactorVerificationScreen(
            userId: result.user!.id,
            email: result.email ?? _emailController.text.trim(),
            codeType: method,
            onVerified: () async {
              // After 2FA is verified, get profile and complete setup
              final profile = await ref.read(currentProfileProvider.future);
              if (profile != null && mounted) {
                await _complete2FASetup(profile.role);
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _complete2FASetup(String userRole) async {
    if (!mounted) return;

    // Complete 2FA and register device
    await ref.read(authNotifierProvider.notifier).completeTwoFactor(
          registerDevice: true,
          enableBiometric: false,
        );

    if (mounted) {
      _navigateToDashboard(userRole);
    }
  }

  Future<void> _showRoleMismatchDialog(String actualRole) async {
    final actualRoleTitle = _formatRole(actualRole);
    final actualRoleColor = _getRoleColor(actualRole);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 8),
            const Expanded(child: Text('Wrong Role Selected')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This account is registered as:',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: actualRoleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: actualRoleColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_getRoleIcon(actualRole), color: actualRoleColor),
                  const SizedBox(width: 12),
                  Text(
                    actualRoleTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: actualRoleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You selected "$_roleTitle" but your account is registered as "$actualRoleTitle". '
              'Please go back and select the correct role.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Go back to role selection
              context.go(RouteNames.roleSelection);
            },
            child: const Text('Go to Role Selection'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'doctor':
        return AppColors.doctor;
      case 'pharmacist':
        return AppColors.pharmacist;
      default:
        return AppColors.patient;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'pharmacist':
        return Icons.local_pharmacy_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'patient':
      default:
        return 'Patient';
    }
  }

  void _navigateToDashboard(String role) {
    switch (role) {
      case 'doctor':
        context.go(RouteNames.doctorDashboard);
        break;
      case 'pharmacist':
        context.go(RouteNames.pharmacistDashboard);
        break;
      default:
        context.go(RouteNames.patientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: size.height * 0.04),

                // ── Back button ─────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
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

                SizedBox(height: size.height * 0.03),

                // ── 1. LOGO & BRANDING ──────────────────────────
                Center(
                  child: Image.asset(
                    'assets/logo_foreground.png',
                    height: 150,
                    width: 150,
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
                  'Sign in to your healthcare account',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    letterSpacing: 0.1,
                  ),
                ),

                SizedBox(height: size.height * 0.05),

                // ── 2. INPUT FIELDS ─────────────────────────────
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
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password is required';
                    if (value.length < 6) return 'Must be at least 6 characters';
                    return null;
                  },
                ),

                // Forgot password — flush right, minimal gap
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: _roleColor,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 8),

                // ── 3. SIGN IN BUTTON ───────────────────────────
                GestureDetector(
                  onTap: _isLoading ? null : _signIn,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D0D0D).withValues(alpha: 0.15),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'SIGN IN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── 4. SIGN UP PROMPT ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?  ",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(RouteNames.signUp, extra: widget.role),
                      child: Text(
                        'Sign Up',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _roleColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── 5. SECURITY NOTE ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, size: 13, color: const Color(0xFF9CA3AF)),
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

                SizedBox(height: size.height * 0.02),
              ],
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

