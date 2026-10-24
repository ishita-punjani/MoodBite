import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import 'auth_repository.dart';

/// Second sign-in step. On success the session controller redirects
/// to profile completion or home.
class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  static const resendCooldown = Duration(seconds: 30);

  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  /// Call inside setState (or from initState).
  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = resendCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmailOtp(email: widget.email, code: _code.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailOtp(widget.email);
      if (!mounted) return;
      setState(() {
        _startCooldown();
        _info = 'A new code is on its way.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (widget.email.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.signIn),
            child: const Text('Enter your email to get a code'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Enter code')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('We sent a 6-digit code to', style: textTheme.bodyMedium),
                Text(widget.email, style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(Validators.otpLength),
                  ],
                  decoration: const InputDecoration(
                    labelText: '6-digit code',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: Validators.otp,
                  onFieldSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
                ],
                if (_info != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_info!, style: textTheme.bodyMedium?.copyWith(color: AppColors.success)),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify and continue'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _busy || _secondsLeft > 0 ? null : _resend,
                  child: Text(_secondsLeft > 0 ? 'Resend code in ${_secondsLeft}s' : 'Resend code'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => context.go(AppRoutes.signIn),
                  child: const Text('Use a different email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
