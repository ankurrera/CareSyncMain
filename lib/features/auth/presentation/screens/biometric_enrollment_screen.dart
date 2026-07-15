import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/kyc_service.dart';
import '../../providers/auth_provider.dart';

class BiometricEnrollmentScreen extends ConsumerStatefulWidget {
  final bool isMandatory;

  const BiometricEnrollmentScreen({super.key, this.isMandatory = false});

  @override
  ConsumerState<BiometricEnrollmentScreen> createState() =>
      _BiometricEnrollmentScreenState();
}

class _BiometricEnrollmentScreenState
    extends ConsumerState<BiometricEnrollmentScreen> {
  bool _isLoading = false;
  bool _isEnrolling = false;

  @override
  void initState() {
    super.initState();
    // Trigger biometric setup at the right lifecycle moment
    if (widget.isMandatory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndEnrollBiometric();
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.tokens.accent),
    );
  }

  Future<void> _checkAndEnrollBiometric() async {
    await _enrollBiometric();
  }

  Future<void> _enrollBiometric() async {
    setState(() {
      _isLoading = true;
      _isEnrolling = true;
    });

    try {
      // KYC check - use robust method
      if (!widget.isMandatory) {
        final session = ref.read(authStateProvider).valueOrNull;
        if (session == null) {
          if (mounted) _snack('Session expired. Please sign in again.');
          return;
        }

        final kycService = KYCService.instance;
        final kycVerified = await kycService.isKYCVerified(session.id);

        if (!kycVerified) {
          if (mounted) {
            _snack('KYC verification required before enabling biometric login');
            context.push(RouteNames.kycVerification);
          }
          return;
        }
      }

      await ref.read(authNotifierProvider.notifier).enrollBiometric();

      if (mounted) {
        _snack('Biometric login enabled successfully!');
        _navigateToDashboard();
      }
    } catch (e) {
      if (mounted) _snack(_extractErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isEnrolling = false;
        });
      }
    }
  }

  void _skipBiometric() {
    _navigateToDashboard();
  }

  /// Extract user-friendly error message from exception
  String _extractErrorMessage(Object error) {
    String errorMessage = error.toString();

    // Remove common exception prefixes
    final prefixes = ['Exception: ', 'AuthException: ', 'BiometricException: '];
    for (final prefix in prefixes) {
      if (errorMessage.startsWith(prefix)) {
        return errorMessage.substring(prefix.length);
      }
    }

    return errorMessage;
  }

  void _navigateToDashboard() {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    switch (profile?.role) {
      case 'doctor':
        context.go(RouteNames.doctorDashboard);
        break;
      case 'pharmacist':
        context.go(RouteNames.pharmacistDashboard);
        break;
      case 'patient':
      default:
        context.go(RouteNames.patientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final biometricAvailable = ref.watch(biometricAvailableProvider);
    final biometricTypeName = ref.watch(biometricTypeNameProvider);

    return Scaffold(
      backgroundColor: t.scaffold,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              const Spacer(),
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isEnrolling ? 160 : 140,
                height: _isEnrolling ? 160 : 140,
                decoration: BoxDecoration(
                  color: t.tint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: t.accent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: biometricTypeName.when(
                    data:
                        (typeName) => Icon(
                          typeName == 'Face ID'
                              ? Iconsax.scan
                              : Iconsax.finger_scan,
                          size: 72,
                          color: t.accent,
                        ),
                    loading: () => const CircularProgressIndicator(),
                    error:
                        (_, __) => Icon(
                          Iconsax.finger_scan,
                          size: 72,
                          color: t.accent,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Title
              biometricTypeName.when(
                data:
                    (typeName) => Text(
                      'Enable $typeName',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                loading:
                    () => Text(
                      'Enable Biometric Login',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                error:
                    (_, __) => Text(
                      'Enable Biometric Login',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use your biometrics for quick and secure sign-in on this device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: t.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Benefits list
              SquircleCard(
                radius: AppSpacing.squircleGrouped,
                borderSide: BorderSide(color: t.divider),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBenefitRow(
                      Iconsax.flash_1,
                      'Quick Access',
                      'Sign in instantly without typing',
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitRow(
                      Iconsax.shield_tick,
                      'Secure',
                      'Your biometric data never leaves the device',
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitRow(
                      Iconsax.mobile,
                      'Device-Specific',
                      'Each device has its own secure enrollment',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Buttons
              biometricAvailable.when(
                data: (available) {
                  if (!available) {
                    return Column(
                      children: [
                        SquircleCard(
                          radius: AppSpacing.squircleGrouped,
                          color: t.tint,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Iconsax.info_circle, color: t.accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Biometric authentication is not available on this device.',
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        CSPrimaryButton(
                          label: 'Continue',
                          onPressed: _skipBiometric,
                        ),
                      ],
                    );
                  }

                  final enableLabel = biometricTypeName.when(
                    data: (typeName) => 'Enable $typeName',
                    loading: () => 'Enable Biometric',
                    error: (_, __) => 'Enable Biometric',
                  );

                  return Column(
                    children: [
                      CSPrimaryButton(
                        label: enableLabel,
                        loading: _isLoading,
                        onPressed: _enrollBiometric,
                      ),
                      // Only show skip button if not mandatory
                      if (!widget.isMandatory) ...[
                        const SizedBox(height: 12),
                        CSSecondaryButton(
                          label: 'Skip for now',
                          onPressed: _isLoading ? null : _skipBiometric,
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error:
                    (_, __) => CSPrimaryButton(
                      label: 'Continue',
                      onPressed: _skipBiometric,
                    ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String subtitle) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: t.tint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: t.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: t.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
