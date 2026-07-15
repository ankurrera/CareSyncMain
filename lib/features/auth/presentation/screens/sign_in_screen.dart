import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/circular_icon_button.dart';
import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/minimal_sheet_dialog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../providers/auth_provider.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(authNotifierProvider.notifier)
          .signIn(
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
            // Show a sheet with the correct role info
            await _showRoleMismatchSheet(profile.role);
          }
          return;
        }

        // Handle different requirements based on sign-in result
        if (result.requiresKyc && mounted) {
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
            backgroundColor: context.tokens.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRoleMismatchSheet(String actualRole) async {
    final actualRoleTitle = _formatRole(actualRole);

    await showAppSheet<void>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        return AppSheetContent(
          icon: Iconsax.warning_2,
          title: 'Wrong Role Selected',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: t.tint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getRoleIcon(actualRole), color: t.accent),
                  const SizedBox(width: 12),
                  Text(
                    actualRoleTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: t.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You selected "$_roleTitle" but your account is registered as '
              '"$actualRoleTitle". Please go back and select the correct role.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            CSPrimaryButton(
              label: 'Go to Role Selection',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(RouteNames.roleSelection);
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Iconsax.health;
      case 'pharmacist':
        return Iconsax.hospital;
      default:
        return Iconsax.user;
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
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: size.height * 0.02),

                // ── Back button ─────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircularIconButton(
                    icon: Iconsax.arrow_left_2,
                    onTap: () => context.pop(),
                  ),
                ),

                SizedBox(height: size.height * 0.02),

                // ── 1. LOGO & BRANDING ──────────────────────────
                Center(
                  child: Image.asset(
                    'assets/logo_foreground.png',
                    height: 130,
                    width: 130,
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
                  'Sign in to your healthcare account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.textSecondary),
                ),

                SizedBox(height: size.height * 0.045),

                // ── 2. INPUT FIELDS ─────────────────────────────
                _buildLabel('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
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
                _buildLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                  cursorColor: t.accent,
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
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
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // Forgot password — flush right, minimal gap
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: t.accent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 8),

                // ── 3. SIGN IN BUTTON ───────────────────────────
                CSPrimaryButton(
                  label: 'Sign In',
                  loading: _isLoading,
                  onPressed: _signIn,
                ),

                const SizedBox(height: 28),

                // ── 4. SIGN UP PROMPT ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?  ",
                      style: TextStyle(fontSize: 13, color: t.textSecondary),
                    ),
                    GestureDetector(
                      onTap:
                          () => context.push(
                            RouteNames.signUp,
                            extra: widget.role,
                          ),
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.accent,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── 5. SECURITY NOTE ────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.shield_tick, size: 13, color: t.textSecondary),
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

                SizedBox(height: size.height * 0.02),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
