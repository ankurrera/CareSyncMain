import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/cs_buttons.dart';
import '../../../../core/design/linear_fade_appbar.dart';
import '../../../../core/design/squircle_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/two_factor_service.dart';
import '../../../../routing/screen_titles.dart';

class TwoFactorVerificationScreen extends ConsumerStatefulWidget {
  final String userId;
  final String email;
  final String? phoneNumber;
  final TwoFactorCodeType codeType;
  final VoidCallback onVerified;

  const TwoFactorVerificationScreen({
    super.key,
    required this.userId,
    required this.email,
    this.phoneNumber,
    required this.codeType,
    required this.onVerified,
  });

  @override
  ConsumerState<TwoFactorVerificationScreen> createState() =>
      _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState
    extends ConsumerState<TwoFactorVerificationScreen> {
  final _codeController = TextEditingController();
  final _twoFactorService = TwoFactorService.instance;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.tokens.error : context.tokens.accent,
      ),
    );
  }

  Future<void> _sendCode() async {
    setState(() => _isLoading = true);

    try {
      if (widget.codeType == TwoFactorCodeType.email) {
        await _twoFactorService.sendEmailCode(
          userId: widget.userId,
          email: widget.email,
        );
      } else if (widget.codeType == TwoFactorCodeType.sms) {
        if (widget.phoneNumber == null) {
          throw Exception('Phone number is required for SMS verification');
        }
        await _twoFactorService.sendSMSCode(
          userId: widget.userId,
          phoneNumber: widget.phoneNumber!,
        );
      }

      if (mounted) {
        _snack(
          'Verification code sent to ${widget.codeType == TwoFactorCodeType.email ? 'email' : 'phone'}',
        );
        // Start countdown
        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) _snack('Failed to send code: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _resendCountdown--);
        return _resendCountdown > 0;
      }
      return false;
    });
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);

    try {
      await _twoFactorService.resendCode(
        userId: widget.userId,
        codeType: widget.codeType,
        email: widget.codeType == TwoFactorCodeType.email ? widget.email : null,
        phoneNumber:
            widget.codeType == TwoFactorCodeType.sms
                ? widget.phoneNumber
                : null,
      );

      if (mounted) {
        _snack('Verification code resent');
        _startResendCountdown();
      }
    } catch (e) {
      if (mounted) _snack('Failed to resend code: $e', error: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      _snack('Please enter a valid 6-digit code', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verified = await _twoFactorService.verifyCode(
        userId: widget.userId,
        code: code,
        codeType: widget.codeType,
      );

      if (verified && mounted) {
        _snack('Verification successful');
        // Call the onVerified callback
        widget.onVerified();
      }
    } catch (e) {
      if (mounted) _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isEmail = widget.codeType == TwoFactorCodeType.email;

    return CSScaffold(
      title: ScreenTitles.twoFactorVerification,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            // Icon
            Icon(
              isEmail ? Iconsax.sms : Iconsax.call,
              size: 72,
              color: t.accent,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Verify Your Identity',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtitle
            Text(
              'We sent a 6-digit code to ${isEmail ? widget.email : widget.phoneNumber}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Code Input
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              cursorColor: t.accent,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: t.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.divider, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: t.divider, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (value.length == 6) {
                  _verifyCode();
                }
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // Verify Button
            CSPrimaryButton(
              label: 'Verify Code',
              loading: _isLoading,
              onPressed: _verifyCode,
            ),
            const SizedBox(height: AppSpacing.md),

            // Resend Code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive the code?",
                  style: TextStyle(color: t.textSecondary),
                ),
                const SizedBox(width: 4),
                if (_resendCountdown > 0)
                  Text(
                    'Resend in ${_resendCountdown}s',
                    style: TextStyle(
                      color: t.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  TextButton(
                    onPressed: _isResending ? null : _resendCode,
                    child:
                        _isResending
                            ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Resend Code'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Help Text
            SquircleCard(
              radius: AppSpacing.squircleGrouped,
              borderSide: BorderSide(color: t.divider),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        size: 20,
                        color: t.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Security Tips',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: t.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Never share your verification code with anyone\n'
                    '• CareSync will never ask for your code\n'
                    '• Code expires in 10 minutes\n'
                    '• Maximum 3 attempts allowed',
                    style: TextStyle(fontSize: 12, color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
